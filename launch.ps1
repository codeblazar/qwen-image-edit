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
        # Production mode with Cloudflare Tunnel
        if (-not (Test-CloudflaredInstalled)) {
            Write-Host ""
            Write-Host "[ERROR] cloudflared not found!" -ForegroundColor Red
            Write-Host "Install with: winget install --id Cloudflare.cloudflared" -ForegroundColor Yellow
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
        
        # Wait for API to start
        Write-Host "Waiting for API to start..." -ForegroundColor Yellow
        $maxAttempts = 15
        $attempt = 0
        $apiReady = $false
        
        while ($attempt -lt $maxAttempts -and -not $apiReady) {
            Start-Sleep -Seconds 1
            $attempt++
            try {
                $response = Invoke-WebRequest -Uri "http://localhost:8000/api/v1/health" -TimeoutSec 2 -ErrorAction SilentlyContinue
                if ($response.StatusCode -eq 200) {
                    $apiReady = $true
                }
            } catch {
                Write-Host "." -NoNewline -ForegroundColor Gray
            }
        }
        
        if (-not $apiReady) {
            Write-Host ""
            Write-Host "[WARNING] API may not be ready yet, but continuing..." -ForegroundColor Yellow
        } else {
            Write-Host ""
            Write-Host "[OK] API is ready!" -ForegroundColor Green
        }
        
        # Start Cloudflare Tunnel
        Write-Host "Starting Cloudflare Tunnel..." -ForegroundColor Cyan
        
        # Verify tunnel config exists
        $configPath = "$env:USERPROFILE\.cloudflared\config.yml"
        if (-not (Test-Path $configPath)) {
            Write-Host ""
            Write-Host "[WARNING] Cloudflare tunnel config not found at: $configPath" -ForegroundColor Yellow
            Write-Host "Tunnel may not work correctly. Run .\tunnel-debug.ps1 status for diagnostics" -ForegroundColor Yellow
            Write-Host ""
        }
        
        # Create temp script for tunnel
        $tunnelTempScript = "$env:TEMP\start-qwen-tunnel.ps1"
        $tunnelScriptContent = @'
$host.UI.RawUI.WindowTitle = 'Cloudflare Tunnel - qwen.codeblazar.org'
Write-Host '====================================================' -ForegroundColor Cyan
Write-Host '  CLOUDFLARE TUNNEL' -ForegroundColor Green
Write-Host '====================================================' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Tunnel: qwen.codeblazar.org -> localhost:8000' -ForegroundColor White
Write-Host 'Press Ctrl+C to stop the tunnel' -ForegroundColor Yellow
Write-Host ''
cloudflared tunnel --loglevel info run qwen
if ($LASTEXITCODE -ne 0) {
    Write-Host ''
    Write-Host '====================================================' -ForegroundColor Red
    Write-Host '  TUNNEL ERROR' -ForegroundColor Red
    Write-Host '====================================================' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Tunnel failed to start. Common issues:' -ForegroundColor Yellow
    Write-Host '  1. Tunnel not authenticated' -ForegroundColor White
    Write-Host '  2. Missing credentials file' -ForegroundColor White
    Write-Host '  3. Tunnel deleted from dashboard' -ForegroundColor White
    Write-Host ''
    Write-Host 'Run diagnostics: .\tunnel-debug.ps1 status' -ForegroundColor Cyan
}
Write-Host ''
Write-Host 'Tunnel stopped. Press any key to close...' -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
'@
        Set-Content -Path $tunnelTempScript -Value $tunnelScriptContent
        $tunnelProcess = Start-Process powershell -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", $tunnelTempScript -PassThru
        
        # Give tunnel time to start
        Write-Host "Waiting for tunnel to establish connection..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
        
        # Check if tunnel process is still running
        $tunnelStillRunning = Get-Process -Id $tunnelProcess.Id -ErrorAction SilentlyContinue
        if (-not $tunnelStillRunning) {
            Write-Host ""
            Write-Host "[WARNING] Tunnel process exited unexpectedly!" -ForegroundColor Red
            Write-Host "Check the tunnel window for error details" -ForegroundColor Yellow
            Write-Host "Or run: .\tunnel-debug.ps1 status" -ForegroundColor Cyan
            Write-Host ""
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
        Write-Host "  [!] Allow 10-15 seconds for tunnel to connect" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "API Key:" -ForegroundColor Yellow
        Write-Host "  $apiKey" -ForegroundColor White
        Write-Host ""
        Write-Host "Background Processes:" -ForegroundColor Gray
        Write-Host "  API Server (PID: $($apiProcess.Id))" -ForegroundColor Gray
        Write-Host "  Tunnel (PID: $($tunnelProcess.Id))" -ForegroundColor Gray
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
        
        Start-Sleep -Seconds 3
        
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
