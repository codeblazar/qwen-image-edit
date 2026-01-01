# Cloudflare Tunnel Debug & Management Script
# For diagnosing issues with qwen.codeblazar.org tunnel

param(
    [Parameter()]
    [ValidateSet("status", "start", "stop", "restart", "test")]
    [string]$Action = "status"
)

$ErrorActionPreference = "Continue"

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor White
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Test-CloudflaredInstalled {
    Write-Section "Checking cloudflared installation"
    
    $cloudflared = Get-Command cloudflared -ErrorAction SilentlyContinue
    if ($null -eq $cloudflared) {
        Write-Host "[X] cloudflared NOT FOUND" -ForegroundColor Red
        Write-Host ""
        Write-Host "Install with:" -ForegroundColor Yellow
        Write-Host "  winget install --id Cloudflare.cloudflared" -ForegroundColor White
        return $false
    }
    
    $version = & cloudflared version 2>&1 | Select-Object -First 1
    Write-Host "[OK] cloudflared installed: $version" -ForegroundColor Green
    Write-Host "  Location: $($cloudflared.Source)" -ForegroundColor Gray
    return $true
}

function Get-TunnelInfo {
    Write-Section "Tunnel Configuration"
    
    # Check config file
    $configPath = "$env:USERPROFILE\.cloudflared\config.yml"
    if (Test-Path $configPath) {
        Write-Host "[OK] Config file found: $configPath" -ForegroundColor Green
        Write-Host ""
        Write-Host "Configuration:" -ForegroundColor Cyan
        Get-Content $configPath | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
    } else {
        Write-Host "[X] Config file NOT FOUND: $configPath" -ForegroundColor Red
        return $false
    }
    
    Write-Host ""
    Write-Host "Tunnel List:" -ForegroundColor Cyan
    cloudflared tunnel list 2>&1 | ForEach-Object { 
        if ($_ -match "qwen") {
            Write-Host "  $_" -ForegroundColor Green
        } else {
            Write-Host "  $_" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-Host "Tunnel Details:" -ForegroundColor Cyan
    cloudflared tunnel info qwen 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
    
    return $true
}

function Get-ProcessInfo {
    Write-Section "Running Processes"
    
    # Check API on port 8000
    $port8000 = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue
    if ($port8000) {
        $apiProcess = Get-Process -Id $port8000.OwningProcess -ErrorAction SilentlyContinue
        Write-Host "[OK] API Server running on port 8000" -ForegroundColor Green
        Write-Host "  Process: $($apiProcess.ProcessName) (PID: $($apiProcess.Id))" -ForegroundColor Gray
        Write-Host "  CPU: $($apiProcess.CPU)" -ForegroundColor Gray
        Write-Host "  Memory: $([math]::Round($apiProcess.WorkingSet64 / 1MB, 2)) MB" -ForegroundColor Gray
    } else {
        Write-Host "[X] No API Server running on port 8000" -ForegroundColor Red
    }
    
    Write-Host ""
    
    # Check cloudflared processes
    $cloudflaredProcesses = Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue
    if ($cloudflaredProcesses) {
        Write-Host "[OK] Cloudflared processes found:" -ForegroundColor Green
        foreach ($proc in $cloudflaredProcesses) {
            Write-Host "  PID: $($proc.Id) | CPU: $($proc.CPU) | Memory: $([math]::Round($proc.WorkingSet64 / 1MB, 2)) MB" -ForegroundColor Gray
            Write-Host "  Start Time: $($proc.StartTime)" -ForegroundColor Gray
            Write-Host ""
        }
    } else {
        Write-Host "[X] No cloudflared processes running" -ForegroundColor Red
    }
}

function Test-APIEndpoint {
    Write-Section "Testing API Endpoint"
    
    # Test localhost
    try {
        Write-Host "Testing http://localhost:8000/api/v1/health ..." -ForegroundColor Cyan
        $response = Invoke-WebRequest -Uri "http://localhost:8000/api/v1/health" -TimeoutSec 5 -UseBasicParsing
        Write-Host "[OK] Local API responsive (Status: $($response.StatusCode))" -ForegroundColor Green
        Write-Host "  Response: $($response.Content)" -ForegroundColor Gray
    } catch {
        Write-Host "[X] Local API not responding" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Gray
        return $false
    }
    
    Write-Host ""
    
    # Test public URL
    try {
        Write-Host "Testing https://qwen.codeblazar.org/api/v1/health ..." -ForegroundColor Cyan
        $response = Invoke-WebRequest -Uri "https://qwen.codeblazar.org/api/v1/health" -TimeoutSec 10 -UseBasicParsing
        Write-Host "[OK] Public API responsive via Cloudflare (Status: $($response.StatusCode))" -ForegroundColor Green
        Write-Host "  Response: $($response.Content)" -ForegroundColor Gray
        
        # Check headers for cloudflare
        if ($response.Headers['CF-RAY']) {
            Write-Host "  [OK] Cloudflare headers detected (CF-RAY: $($response.Headers['CF-RAY']))" -ForegroundColor Green
        }
    } catch {
        Write-Host "[X] Public API not responding" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Gray
        
        if ($_.Exception.Message -match "404") {
            Write-Host ""
            Write-Host "  Possible causes:" -ForegroundColor Yellow
            Write-Host "    1. Tunnel is not running" -ForegroundColor White
            Write-Host "    2. DNS not configured correctly" -ForegroundColor White
            Write-Host "    3. Tunnel configuration mismatch" -ForegroundColor White
        }
        return $false
    }
    
    return $true
}

function Start-Tunnel {
    Write-Section "Starting Cloudflare Tunnel"
    
    # Check if already running
    $existing = Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "[!] Cloudflared already running (PID: $($existing.Id))" -ForegroundColor Yellow
        Write-Host "  Use 'tunnel-debug.ps1 restart' to restart" -ForegroundColor Gray
        return
    }
    
    # Check if API is running
    $port8000 = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue
    if (-not $port8000) {
        Write-Host "[!] WARNING: API Server not detected on port 8000" -ForegroundColor Yellow
        Write-Host "  Tunnel will fail to connect properly" -ForegroundColor Yellow
        $continue = Read-Host "Continue anyway? (y/N)"
        if ($continue -ne "y") {
            Write-Host "Aborted. Start API first with: .\launch.ps1" -ForegroundColor Gray
            return
        }
    }
    
    Write-Host "Starting tunnel in new window with debug logging..." -ForegroundColor Cyan
    Write-Host ""
    
    # Create a temporary script file to launch the tunnel
    $tempScript = "$env:TEMP\start-tunnel.ps1"
    $scriptContent = @'
$host.UI.RawUI.WindowTitle = "Cloudflare Tunnel - qwen.codeblazar.org [DEBUG]"
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "  CLOUDFLARE TUNNEL - DEBUG MODE" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Tunnel: qwen" -ForegroundColor White
Write-Host "Route:  qwen.codeblazar.org -> localhost:8000" -ForegroundColor White
Write-Host ""
Write-Host "Press Ctrl+C to stop the tunnel" -ForegroundColor Yellow
Write-Host ""
cloudflared tunnel --loglevel debug run qwen
Write-Host ""
Write-Host "Tunnel stopped. Press any key to close..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
'@
    
    Set-Content -Path $tempScript -Value $scriptContent
    Start-Process powershell -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", $tempScript
    
    Start-Sleep -Seconds 2
    
    Write-Host "[OK] Tunnel started in new window" -ForegroundColor Green
    Write-Host "  Monitor the tunnel window for detailed logs" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Wait 5-10 seconds, then test with:" -ForegroundColor Cyan
    Write-Host "    .\tunnel-debug.ps1 test" -ForegroundColor White
}

function Stop-Tunnel {
    Write-Section "Stopping Cloudflare Tunnel"
    
    $processes = Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue
    if (-not $processes) {
        Write-Host "[OK] No cloudflared processes running" -ForegroundColor Green
        return
    }
    
    foreach ($proc in $processes) {
        Write-Host "Stopping PID $($proc.Id)..." -ForegroundColor Yellow
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    }
    
    Start-Sleep -Seconds 1
    
    $stillRunning = Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue
    if ($stillRunning) {
        Write-Host "[X] Failed to stop some processes" -ForegroundColor Red
    } else {
        Write-Host "[OK] All cloudflared processes stopped" -ForegroundColor Green
    }
}

# Main execution
switch ($Action) {
    "status" {
        if (-not (Test-CloudflaredInstalled)) { exit 1 }
        Get-TunnelInfo
        Get-ProcessInfo
        
        Write-Section "Quick Status Summary"
        
        $apiRunning = $null -ne (Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue)
        $tunnelRunning = $null -ne (Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue)
        
        Write-Host "API Server (port 8000):  " -NoNewline
        if ($apiRunning) { 
            Write-Host "[OK] Running" -ForegroundColor Green 
        } else { 
            Write-Host "[X] Not Running" -ForegroundColor Red 
        }
        
        Write-Host "Cloudflare Tunnel:       " -NoNewline
        if ($tunnelRunning) { 
            Write-Host "[OK] Running" -ForegroundColor Green 
        } else { 
            Write-Host "[X] Not Running" -ForegroundColor Red 
        }
        
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Cyan
        if (-not $apiRunning) {
            Write-Host "  .\launch.ps1 -> Option 1 (Start API + Tunnel)" -ForegroundColor White
        } elseif (-not $tunnelRunning) {
            Write-Host "  .\tunnel-debug.ps1 start" -ForegroundColor White
        } else {
            Write-Host "  .\tunnel-debug.ps1 test" -ForegroundColor White
        }
    }
    
    "start" {
        if (-not (Test-CloudflaredInstalled)) { exit 1 }
        Start-Tunnel
    }
    
    "stop" {
        Stop-Tunnel
    }
    
    "restart" {
        Stop-Tunnel
        Start-Sleep -Seconds 2
        Start-Tunnel
    }
    
    "test" {
        if (-not (Test-CloudflaredInstalled)) { exit 1 }
        Get-ProcessInfo
        Test-APIEndpoint
    }
}

Write-Host ""
