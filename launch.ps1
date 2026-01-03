# Qwen Image Edit - Simple Launcher Script

$projectRoot = $PSScriptRoot
$activateScript = Join-Path $projectRoot '.venv\Scripts\Activate.ps1'

if (-not (Test-Path $activateScript)) {
    Write-Host "[ERROR] Unable to find virtual environment activation script at $activateScript" -ForegroundColor Red
    Write-Host "Please create the venv with: python -m venv .venv" -ForegroundColor Yellow
    exit 1
}

if (-not $env:VIRTUAL_ENV -or ($env:VIRTUAL_ENV -notlike "*\.venv*")) {
    Write-Host "Activating venv..." -ForegroundColor Cyan
    . $activateScript
} else {
    Write-Host "Using existing virtual environment: $env:VIRTUAL_ENV" -ForegroundColor Cyan
}

function Stop-QwenProcesses {
    # Stop API on port 8000
    $port8000 = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue
    if ($port8000) {
        Write-Host "Stopping existing API process..." -ForegroundColor Yellow
        Stop-Process -Id $port8000.OwningProcess -Force -ErrorAction SilentlyContinue
    }
    
    # Stop Gradio on port 7860
    $port7860 = Get-NetTCPConnection -LocalPort 7860 -ErrorAction SilentlyContinue
    if ($port7860) {
        Write-Host "Stopping existing Gradio process..." -ForegroundColor Yellow
        Stop-Process -Id $port7860.OwningProcess -Force -ErrorAction SilentlyContinue
    }
    
    # Stop cloudflared tunnels
    $cloudflared = Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue
    if ($cloudflared) {
        Write-Host "Stopping existing cloudflared tunnel..." -ForegroundColor Yellow
        Stop-Process -Name "cloudflared" -Force -ErrorAction SilentlyContinue
    }
    
    Start-Sleep -Milliseconds 500
}

function Test-CloudflaredInstalled {
    $cloudflared = Get-Command cloudflared -ErrorAction SilentlyContinue
    return $null -ne $cloudflared
}

function Test-DockerInstalled {
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if ($null -eq $docker) { return $false }

    # External commands typically don't throw on non-zero exit codes.
    # Explicitly check $LASTEXITCODE to verify Docker Desktop daemon is reachable.
    $null = & docker info 2>$null
    if ($LASTEXITCODE -ne 0) { return $false }

    return $true
}

function Get-CloudflareTunnelToken {
    $tokenFile = Join-Path $projectRoot 'cloudflare-tunnel-token.local.txt'
    if ($env:QWEN_CF_TUNNEL_TOKEN -and $env:QWEN_CF_TUNNEL_TOKEN.Trim()) {
        return $env:QWEN_CF_TUNNEL_TOKEN.Trim()
    }
    if (Test-Path $tokenFile) {
        $token = (Get-Content $tokenFile -Raw).Trim()
        if ($token) { return $token }
    }
    return $null
}

function Get-ApiHealth {
    param(
        [Parameter(Mandatory=$true)][string]$Url
    )

    try {
        # Use curl.exe to avoid Invoke-WebRequest parsing/security prompts
        $jsonText = & curl.exe -s --max-time 2 $Url
        if (-not $jsonText) { return $null }
        return $jsonText | ConvertFrom-Json
    } catch {
        return $null
    }
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "    QWEN IMAGE EDIT - LAUNCHER" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[1] API Server + Cloudflare Tunnel (Production)" -ForegroundColor White
Write-Host "    Local:  http://localhost:8000/docs" -ForegroundColor Gray
Write-Host "    Public: https://qwen.codeblazar.org/docs" -ForegroundColor Gray
Write-Host ""
Write-Host "[2] API Server Only (Local Development)" -ForegroundColor White
Write-Host "    Local:  http://localhost:8000/docs" -ForegroundColor Gray
Write-Host ""
Write-Host "[3] Gradio UI (Local Development)" -ForegroundColor White
Write-Host "    Local:  http://localhost:7860" -ForegroundColor Gray
Write-Host ""
Write-Host "[S] Stop All Services" -ForegroundColor Red
Write-Host "[Q] Quit" -ForegroundColor White
Write-Host ""
$choice = Read-Host "Choice (1/2/3/S/Q)"

switch ($choice.ToUpper()) {
    "1" {
        # Production mode with Cloudflare Tunnel (Docker token-based)
        if (-not (Test-DockerInstalled)) {
            Write-Host ""
            Write-Host "[ERROR] Docker Desktop is not running (or not reachable)." -ForegroundColor Red
            Write-Host "Start Docker Desktop and wait until it shows 'Docker is running', then retry." -ForegroundColor Yellow
            Write-Host "(We need Docker to run the Cloudflare Tunnel container.)" -ForegroundColor Gray
            Write-Host ""
            exit 1
        }

        $tunnelToken = Get-CloudflareTunnelToken
        if (-not $tunnelToken) {
            Write-Host ""
            Write-Host "[ERROR] Cloudflare tunnel token not configured." -ForegroundColor Red
            Write-Host "Create cloudflare-tunnel-token.local.txt (ignored by git)" -ForegroundColor Yellow
            Write-Host "or set env var QWEN_CF_TUNNEL_TOKEN." -ForegroundColor Yellow
            Write-Host "See: cloudflare-tunnel-token.local.txt.example" -ForegroundColor Gray
            Write-Host ""
            exit 1
        }
        
        Stop-QwenProcesses
        
        # Check if API key file exists, if not create one
        $keyFile = "$PSScriptRoot\api\.api_key"
        if (-not (Test-Path $keyFile)) {
            Write-Host "No API key found. Generating one..." -ForegroundColor Yellow
            & "$PSScriptRoot\api\manage-key.ps1" -Generate
        }
        
        # Read the API key
        $apiKey = (Get-Content $keyFile -Raw).Trim()
        
        Write-Host ""
        Write-Host "Starting API Server..." -ForegroundColor Cyan
        
        # Create temp script for API
        $apiTempScript = "$env:TEMP\start-qwen-api.ps1"
        $apiScriptContent = @"
& '$activateScript'
Set-Location '$projectRoot\api'
`$host.UI.RawUI.WindowTitle = 'Qwen API Server'
Write-Host 'Starting API Server on port 8000...' -ForegroundColor Green
python main.py
Write-Host ''
Write-Host 'API stopped. Press any key to close...' -ForegroundColor Yellow
`$null = `$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
"@
        Set-Content -Path $apiTempScript -Value $apiScriptContent
        $apiProcess = Start-Process powershell -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", $apiTempScript -PassThru
        
        # Wait for API + model to become ready (reduce polling frequency)
        Write-Host "Waiting for API + model to finish loading..." -ForegroundColor Yellow
        $initialDelaySeconds = 20
        $pollIntervalSeconds = 10
        $maxAttempts = 60  # ~10 minutes after initial delay
        $attempt = 0
        $apiReady = $false

        Start-Sleep -Seconds $initialDelaySeconds

        while ($attempt -lt $maxAttempts -and -not $apiReady) {
            $attempt++
            $health = Get-ApiHealth -Url "http://localhost:8000/api/v1/health"
            if ($health -and $health.status -eq "healthy" -and $health.model_loaded -eq $true -and $health.is_loading -eq $false) {
                $apiReady = $true
            } else {
                Write-Host "." -NoNewline -ForegroundColor Gray
                Start-Sleep -Seconds $pollIntervalSeconds
            }
        }
        
        if (-not $apiReady) {
            Write-Host ""
            Write-Host "[WARNING] API may not be ready yet, but continuing..." -ForegroundColor Yellow
        } else {
            Write-Host ""
            Write-Host "[OK] API is ready!" -ForegroundColor Green
        }

        # Report health/model state (local)
        $localHealth = Get-ApiHealth -Url "http://localhost:8000/api/v1/health"
        if ($localHealth) {
            Write-Host "[HEALTH] Local: status=$($localHealth.status) model_loaded=$($localHealth.model_loaded) current_model=$($localHealth.current_model) is_loading=$($localHealth.is_loading)" -ForegroundColor Gray
        } else {
            Write-Host "[HEALTH] Local: unable to read /api/v1/health" -ForegroundColor Yellow
        }
        
        # Start Cloudflare Tunnel via Docker
        Write-Host "Starting Cloudflare Tunnel (Docker)..." -ForegroundColor Cyan
        docker rm -f qwen-cloudflared 2>$null | Out-Null
        $containerId = docker run -d --rm --name qwen-cloudflared cloudflare/cloudflared:latest tunnel --no-autoupdate run --token $tunnelToken
        
        Write-Host "Waiting for tunnel to establish connection..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5

        # Report health/model state (public) if reachable
        $publicHealth = Get-ApiHealth -Url "https://qwen.codeblazar.org/api/v1/health"
        if ($publicHealth) {
            Write-Host "[HEALTH] Public: status=$($publicHealth.status) model_loaded=$($publicHealth.model_loaded) current_model=$($publicHealth.current_model) is_loading=$($publicHealth.is_loading)" -ForegroundColor Gray
        } else {
            Write-Host "[HEALTH] Public: not reachable yet (tunnel/DNS may still be connecting)" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "====================================================" -ForegroundColor Green
        Write-Host "    [OK] QWEN API + TUNNEL RUNNING" -ForegroundColor Green
        Write-Host "====================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Local Access:" -ForegroundColor Cyan
        Write-Host "  Swagger UI:  http://localhost:8000/docs" -ForegroundColor White
        Write-Host "  Health:      http://localhost:8000/api/v1/health" -ForegroundColor White
        Write-Host ""
        Write-Host "Public Access (Cloudflare Tunnel):" -ForegroundColor Cyan
        Write-Host "  Swagger UI:  https://qwen.codeblazar.org/docs" -ForegroundColor White
        Write-Host "  Health:      https://qwen.codeblazar.org/api/v1/health" -ForegroundColor White
        Write-Host "  Wait for API health confirmation (HTTP 200 / healthy)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "API Key:" -ForegroundColor Yellow
        Write-Host "  $apiKey" -ForegroundColor White
        Write-Host ""
        Write-Host "Background Processes:" -ForegroundColor Gray
        Write-Host "  API Server (PID: $($apiProcess.Id))" -ForegroundColor Gray
        Write-Host "  Tunnel (docker container: qwen-cloudflared)" -ForegroundColor Gray
        Write-Host "  Tunnel Logs: docker logs -f qwen-cloudflared" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Troubleshooting:" -ForegroundColor Cyan
        Write-Host "  Check status:  .\tunnel-debug.ps1 status" -ForegroundColor White
        Write-Host "  Test tunnel:   .\tunnel-debug.ps1 test" -ForegroundColor White
        Write-Host ""
        Write-Host "Management:" -ForegroundColor Cyan
        Write-Host "  Rotate key:    .\api\manage-key.ps1 -Rotate" -ForegroundColor White
        Write-Host "  Stop all:      .\launch.ps1 -> Option S" -ForegroundColor White
        Write-Host ""
    }
    "2" {
        # Local API only
        Stop-QwenProcesses
        
        # Check if API key file exists, if not create one
        $keyFile = "$PSScriptRoot\api\.api_key"
        if (-not (Test-Path $keyFile)) {
            Write-Host "No API key found. Generating one..." -ForegroundColor Yellow
            & "$PSScriptRoot\api\manage-key.ps1" -Generate
        }
        
        # Read the API key
        $apiKey = (Get-Content $keyFile -Raw).Trim()
        
        Write-Host ""
        Write-Host "Starting API Server (Local Only)..." -ForegroundColor Cyan
        
        # Create temp script
        $apiTempScript = "$env:TEMP\start-qwen-api-local.ps1"
        $apiScriptContent = @"
& '$activateScript'
Set-Location '$projectRoot\api'
`$host.UI.RawUI.WindowTitle = 'Qwen API Server (Local)'
Write-Host 'Starting API Server on port 8000...' -ForegroundColor Green
python main.py
Write-Host ''
Write-Host 'API stopped. Press any key to close...' -ForegroundColor Yellow
`$null = `$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
"@
        Set-Content -Path $apiTempScript -Value $apiScriptContent
        $apiProcess = Start-Process powershell -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", $apiTempScript -PassThru
        
        # Wait for API + default model load to complete (reduce polling frequency)
        Write-Host "Waiting for API + model to finish loading..." -ForegroundColor Yellow
        $initialDelaySeconds = 20
        $pollIntervalSeconds = 10
        $maxAttempts = 60  # ~10 minutes after initial delay
        $attempt = 0
        $apiReady = $false

        Start-Sleep -Seconds $initialDelaySeconds

        while ($attempt -lt $maxAttempts -and -not $apiReady) {
            $attempt++
            $health = Get-ApiHealth -Url "http://localhost:8000/api/v1/health"
            if ($health -and $health.status -eq "healthy" -and $health.model_loaded -eq $true -and $health.is_loading -eq $false) {
                $apiReady = $true
            } else {
                Write-Host "." -NoNewline -ForegroundColor Gray
                Start-Sleep -Seconds $pollIntervalSeconds
            }
        }

        Write-Host ""

        # Report health/model state (local)
        $localHealth = Get-ApiHealth -Url "http://localhost:8000/api/v1/health"
        if ($localHealth) {
            Write-Host "[HEALTH] Local: status=$($localHealth.status) model_loaded=$($localHealth.model_loaded) current_model=$($localHealth.current_model) is_loading=$($localHealth.is_loading)" -ForegroundColor Gray
        } else {
            Write-Host "[HEALTH] Local: unable to read /api/v1/health" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "====================================================" -ForegroundColor Green
        Write-Host "    [OK] QWEN API RUNNING (LOCAL)" -ForegroundColor Green
        Write-Host "====================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Swagger UI:  http://localhost:8000/docs" -ForegroundColor White
        Write-Host "  API Key:     $apiKey" -ForegroundColor Yellow
        Write-Host "  Process ID:  $($apiProcess.Id)" -ForegroundColor Gray
        Write-Host ""
    }
    "3" {
        # Gradio UI
        Stop-QwenProcesses
        
        Write-Host ""
        Write-Host "Starting Gradio UI..." -ForegroundColor Cyan
        
        # Create temp script
        $gradioTempScript = "$env:TEMP\start-qwen-gradio.ps1"
        $gradioScriptContent = @"
& '$activateScript'
Set-Location '$projectRoot'
`$host.UI.RawUI.WindowTitle = 'Qwen Gradio UI'
Write-Host 'Starting Gradio UI on port 7860...' -ForegroundColor Green
python qwen_gradio_ui.py
Write-Host ''
Write-Host 'Gradio stopped. Press any key to close...' -ForegroundColor Yellow
`$null = `$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
"@
        Set-Content -Path $gradioTempScript -Value $gradioScriptContent
        $gradioProcess = Start-Process powershell -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", $gradioTempScript -PassThru
        
        Start-Sleep -Seconds 3
        
        Write-Host ""
        Write-Host "====================================================" -ForegroundColor Green
        Write-Host "    [OK] GRADIO UI RUNNING" -ForegroundColor Green
        Write-Host "====================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Gradio UI:   http://localhost:7860" -ForegroundColor White
        Write-Host "  Process ID:  $($gradioProcess.Id)" -ForegroundColor Gray
        Write-Host ""
    }
    "S" {
        # Stop all services
        Write-Host ""
        Write-Host "Stopping all Qwen services..." -ForegroundColor Yellow
        Stop-QwenProcesses
        Write-Host "[OK] All services stopped." -ForegroundColor Green
        Write-Host ""
    }
    "Q" { 
        exit 
    }
    default {
        Write-Host ""
        Write-Host "Invalid choice. Please run again." -ForegroundColor Red
        Write-Host ""
    }
}
