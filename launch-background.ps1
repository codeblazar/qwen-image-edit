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
    
    Start-Sleep -Milliseconds 500
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
        # Check cloudflared
        $cloudflared = Get-Command cloudflared -ErrorAction SilentlyContinue
        if (-not $cloudflared) {
            Write-Host ""
            Write-Host "[ERROR] cloudflared not found!" -ForegroundColor Red
            Write-Host "Install: winget install --id Cloudflare.cloudflared" -ForegroundColor Yellow
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
        
        # Wait for API
        Write-Host "Waiting for API to start..." -ForegroundColor Yellow
        $maxAttempts = 20
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
        
        if ($apiReady) {
            Write-Host ""
            Write-Host "[OK] API is ready!" -ForegroundColor Green
        } else {
            Write-Host ""
            Write-Host "[WARNING] API startup taking longer than expected..." -ForegroundColor Yellow
        }
        
        Write-Host "Starting Cloudflare Tunnel (background)..." -ForegroundColor Cyan
        
        # Start tunnel as background job
        $tunnelJob = Start-Job -ScriptBlock {
            cloudflared tunnel run qwen
        }
        
        Start-Sleep -Seconds 5
        
        # Get process IDs
        $apiPort = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue
        $apiPid = if ($apiPort) { $apiPort.OwningProcess } else { "Unknown" }
        
        $tunnelProc = Get-Process -Name cloudflared -ErrorAction SilentlyContinue
        $tunnelPid = if ($tunnelProc) { $tunnelProc.Id } else { "Unknown" }
        
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
        Write-Host "  Tunnel:      PID $tunnelPid (Job ID: $($tunnelJob.Id))" -ForegroundColor Gray
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
        } else {
            Write-Host "[X] API Server: Not running" -ForegroundColor Red
        }
        
        # Check tunnel
        $tunnelProc = Get-Process -Name cloudflared -ErrorAction SilentlyContinue
        if ($tunnelProc) {
            Write-Host "[OK] Tunnel: Running (PID: $($tunnelProc.Id))" -ForegroundColor Green
            Write-Host "     Memory: $([math]::Round($tunnelProc.WorkingSet64 / 1MB, 2)) MB" -ForegroundColor Gray
        } else {
            Write-Host "[X] Tunnel: Not running" -ForegroundColor Red
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
