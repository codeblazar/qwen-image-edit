# Qwen Image Edit - Background Launcher (No Extra Windows)

$projectRoot = $PSScriptRoot
$activateScript = Join-Path $projectRoot '.venv\Scripts\Activate.ps1'

if (-not (Test-Path $activateScript)) {
    Write-Host "[ERROR] Unable to find virtual environment" -ForegroundColor Red
    exit 1
}

function Stop-QwenProcesses {
    $port8000 = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue
    if ($port8000) {
        Write-Host "Stopping existing API..." -ForegroundColor Yellow
        Stop-Process -Id $port8000.OwningProcess -Force -ErrorAction SilentlyContinue
    }
    
    $cloudflared = Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue
    if ($cloudflared) {
        Write-Host "Stopping existing tunnel..." -ForegroundColor Yellow
        Stop-Process -Name "cloudflared" -Force -ErrorAction SilentlyContinue
    }

    # Stop Docker-based tunnel container if present
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if ($docker) {
        docker rm -f qwen-cloudflared 2>$null | Out-Null
    }
    
    Start-Sleep -Milliseconds 500
}

function Get-CloudflareTunnelToken {
    $tokenFile = Join-Path $projectRoot "cloudflare-tunnel-token.local.txt"
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
        $jsonText = & curl.exe -s --max-time 2 $Url
        if (-not $jsonText) { return $null }
        return $jsonText | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Test-DockerDesktopRunning {
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $docker) { return $false }

    # External commands don't throw on non-zero exit codes; check $LASTEXITCODE.
    $null = & docker info 2>$null
    if ($LASTEXITCODE -ne 0) { return $false }

    return $true
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "    QWEN IMAGE EDIT - BACKGROUND LAUNCHER" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[1] Start API + Tunnel (Background)" -ForegroundColor White
Write-Host "[2] Stop All Services" -ForegroundColor Red
Write-Host "[3] Show Status" -ForegroundColor White
Write-Host "[Q] Quit" -ForegroundColor White
Write-Host ""
$choice = Read-Host "Choice (1/2/3/Q)"

switch ($choice.ToUpper()) {
    "1" {
        # Check Docker (preferred for tunnel) and token
        if (-not (Test-DockerDesktopRunning)) {
            Write-Host ""
            Write-Host "[ERROR] Docker Desktop is not running (or not reachable)." -ForegroundColor Red
            Write-Host "Start Docker Desktop and wait until it shows 'Docker is running', then retry." -ForegroundColor Yellow
            Write-Host "(We need Docker to run the Cloudflare Tunnel container.)" -ForegroundColor Gray
            exit 1
        }
        $token = Get-CloudflareTunnelToken
        if (-not $token) {
            Write-Host ""
            Write-Host "[ERROR] Cloudflare tunnel token not configured." -ForegroundColor Red
            Write-Host "Create cloudflare-tunnel-token.local.txt (ignored by git)" -ForegroundColor Yellow
            Write-Host "or set env var QWEN_CF_TUNNEL_TOKEN." -ForegroundColor Yellow
            Write-Host "See: cloudflare-tunnel-token.local.txt.example" -ForegroundColor Gray
            exit 1
        }
        
        Stop-QwenProcesses
        
        # Check API key
        $keyFile = "$PSScriptRoot\api\.api_key"
        if (-not (Test-Path $keyFile)) {
            Write-Host "Generating API key..." -ForegroundColor Yellow
            & "$PSScriptRoot\api\manage-key.ps1" -Generate
        }
        $apiKey = (Get-Content $keyFile -Raw).Trim()
        
        Write-Host ""
        Write-Host "Starting API Server (background)..." -ForegroundColor Cyan
        
        # Start API as background job
        $apiJob = Start-Job -ScriptBlock {
            param($activateScript, $apiPath)
            & $activateScript
            Set-Location $apiPath
            python main.py
        } -ArgumentList $activateScript, "$projectRoot\api"
        
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
        
        if ($apiReady) {
            Write-Host ""
            Write-Host "[OK] API is ready!" -ForegroundColor Green
        } else {
            Write-Host ""
            Write-Host "[WARNING] API startup taking longer than expected..." -ForegroundColor Yellow
        }

        # Report health/model state (local)
        $localHealth = Get-ApiHealth -Url "http://localhost:8000/api/v1/health"
        if ($localHealth) {
            Write-Host "[HEALTH] Local: status=$($localHealth.status) model_loaded=$($localHealth.model_loaded) current_model=$($localHealth.current_model) is_loading=$($localHealth.is_loading)" -ForegroundColor Gray
        } else {
            Write-Host "[HEALTH] Local: unable to read /api/v1/health" -ForegroundColor Yellow
        }
        
        Write-Host "Starting Cloudflare Tunnel (background)..." -ForegroundColor Cyan

        # Start tunnel container (detached)
        docker rm -f qwen-cloudflared 2>$null | Out-Null
        $containerId = docker run -d --rm --name qwen-cloudflared cloudflare/cloudflared:latest tunnel --no-autoupdate run --token $token
        Start-Sleep -Seconds 2

        # Report health/model state (public) if reachable
        $publicHealth = Get-ApiHealth -Url "https://qwen.codeblazar.org/api/v1/health"
        if ($publicHealth) {
            Write-Host "[HEALTH] Public: status=$($publicHealth.status) model_loaded=$($publicHealth.model_loaded) current_model=$($publicHealth.current_model) is_loading=$($publicHealth.is_loading)" -ForegroundColor Gray
        } else {
            Write-Host "[HEALTH] Public: not reachable yet (tunnel/DNS may still be connecting)" -ForegroundColor Yellow
        }
        
        # Get process IDs
        $apiPort = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue
        $apiPid = if ($apiPort) { ($apiPort.OwningProcess | Select-Object -Unique | Select-Object -First 1) } else { "Unknown" }
        
        $tunnelPid = "docker:$($containerId.Substring(0, [Math]::Min(12, $containerId.Length)))"
        
        Write-Host ""
        Write-Host "====================================================" -ForegroundColor Green
        Write-Host "    [OK] SERVICES RUNNING IN BACKGROUND" -ForegroundColor Green
        Write-Host "====================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Access URLs:" -ForegroundColor Cyan
        Write-Host "  Local:   http://localhost:8000/docs" -ForegroundColor White
        Write-Host "  Public:  https://qwen.codeblazar.org/docs" -ForegroundColor White
        Write-Host ""
        Write-Host "API Key (REQUIRED for all requests):" -ForegroundColor Yellow
        Write-Host "  $apiKey" -ForegroundColor White
        Write-Host ""
        Write-Host "  Add this header to all API requests:" -ForegroundColor Gray
        Write-Host "  X-API-Key: $apiKey" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Background Processes:" -ForegroundColor Gray
        Write-Host "  API Server:  PID $apiPid (Job ID: $($apiJob.Id))" -ForegroundColor Gray
        Write-Host "  Tunnel:      $tunnelPid (container: qwen-cloudflared)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "To stop: .\launch-background.ps1 -> Option 2" -ForegroundColor Cyan
        Write-Host "To check: .\tunnel-debug.ps1 test" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "IMPORTANT: DO NOT CLOSE THIS WINDOW!" -ForegroundColor Red
        Write-Host "Services run as PowerShell background jobs and will stop if you close this window." -ForegroundColor Yellow
        Write-Host "Minimize this window instead. Use 'Get-Job' to see jobs." -ForegroundColor Yellow
        Write-Host ""
    }
    
    "2" {
        Write-Host ""
        Write-Host "Stopping all services..." -ForegroundColor Yellow
        
        # Stop jobs
        Get-Job | Stop-Job
        Get-Job | Remove-Job
        
        # Stop processes
        Stop-QwenProcesses
        
        Write-Host "[OK] All services stopped." -ForegroundColor Green
        Write-Host ""
    }
    
    "3" {
        Write-Host ""
        Write-Host "====================================================" -ForegroundColor Cyan
        Write-Host "    SERVICE STATUS" -ForegroundColor White
        Write-Host "====================================================" -ForegroundColor Cyan
        Write-Host ""
        
        # Check API
        $apiPort = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue
        if ($apiPort) {
            $apiProc = Get-Process -Id $apiPort.OwningProcess -ErrorAction SilentlyContinue
            Write-Host "[OK] API Server: Running (PID: $($apiPort.OwningProcess))" -ForegroundColor Green
            Write-Host "     Memory: $([math]::Round($apiProc.WorkingSet64 / 1MB, 2)) MB" -ForegroundColor Gray

            $localHealth = Get-ApiHealth -Url "http://localhost:8000/api/v1/health"
            if ($localHealth) {
                Write-Host "     Health: status=$($localHealth.status) model_loaded=$($localHealth.model_loaded) current_model=$($localHealth.current_model) is_loading=$($localHealth.is_loading)" -ForegroundColor Gray
            } else {
                Write-Host "     Health: unable to read /api/v1/health" -ForegroundColor Yellow
            }
        } else {
            Write-Host "[X] API Server: Not running" -ForegroundColor Red
        }
        
        # Check tunnel (Docker container)
        $docker = Get-Command docker -ErrorAction SilentlyContinue
        if ($docker) {
            $cid = docker ps --filter "name=^/qwen-cloudflared$" --format "{{.ID}}" 2>$null
            if ($cid) {
                Write-Host "[OK] Tunnel: Running (docker container qwen-cloudflared)" -ForegroundColor Green
                Write-Host "     Container ID: $cid" -ForegroundColor Gray
            } else {
                Write-Host "[X] Tunnel: Not running (docker container qwen-cloudflared not found)" -ForegroundColor Red
            }
        } else {
            Write-Host "[!] Tunnel: Docker not available" -ForegroundColor Yellow
        }
        
        # Check jobs
        Write-Host ""
        Write-Host "Background Jobs:" -ForegroundColor Cyan
        $jobs = Get-Job
        if ($jobs) {
            $jobs | Format-Table Id, Name, State
        } else {
            Write-Host "  No active jobs" -ForegroundColor Gray
        }
        
        # Get API key
        $keyFile = "$PSScriptRoot\api\.api_key"
        if (Test-Path $keyFile) {
            $apiKey = (Get-Content $keyFile -Raw).Trim()
            Write-Host ""
            Write-Host "API Key: $apiKey" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "For detailed diagnostics: .\tunnel-debug.ps1 status" -ForegroundColor Cyan
        Write-Host ""
    }
    
    "Q" {
        exit
    }
}
