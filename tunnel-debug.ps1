# Cloudflare Tunnel Debug & Management Script
# For diagnosing issues with qwen.codeblazar.org tunnel

param(
    [Parameter()]
    [ValidateSet("status", "start", "stop", "restart", "test")]
    [string]$Action = "status"
)

$ErrorActionPreference = "Continue"

$ProjectRoot = $PSScriptRoot
$TokenFilePath = Join-Path $ProjectRoot "cloudflare-tunnel-token.local.txt"

function Get-CloudflareTunnelToken {
    if ($env:QWEN_CF_TUNNEL_TOKEN -and $env:QWEN_CF_TUNNEL_TOKEN.Trim()) {
        return $env:QWEN_CF_TUNNEL_TOKEN.Trim()
    }
    if (Test-Path $TokenFilePath) {
        $token = (Get-Content $TokenFilePath -Raw).Trim()
        if ($token) { return $token }
    }
    return $null
}

function Test-DockerInstalled {
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if ($null -eq $docker) {
        return $false
    }
    try {
        $null = & docker version 2>$null
        return $true
    } catch {
        return $false
    }
}

function Get-DockerTunnelContainerName {
    return "qwen-cloudflared"
}

function Get-DockerTunnelStatus {
    $name = Get-DockerTunnelContainerName
    if (-not (Test-DockerInstalled)) {
        return $null
    }
    try {
        $out = & docker ps --filter "name=^/${name}$" --format "{{.ID}}" 2>$null
        if ($out) { return $out.Trim() }
        return ""
    } catch {
        return $null
    }
}

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

    $token = Get-CloudflareTunnelToken
    if ($token) {
        Write-Host "[OK] Token-based tunnel configured (Docker mode)" -ForegroundColor Green
        Write-Host "  Token source: " -NoNewline -ForegroundColor Gray
        if ($env:QWEN_CF_TUNNEL_TOKEN) {
            Write-Host "env:QWEN_CF_TUNNEL_TOKEN" -ForegroundColor White
        } else {
            Write-Host "$TokenFilePath" -ForegroundColor White
        }
        Write-Host "  Note: The token itself is not printed." -ForegroundColor Gray
        return $true
    }
    
    # Check config file
    $configPath = "$env:USERPROFILE\.cloudflared\config.yml"
    if (Test-Path $configPath) {
        Write-Host "[OK] Config file found: $configPath" -ForegroundColor Green
        Write-Host ""
        Write-Host "Configuration:" -ForegroundColor Cyan
        Get-Content $configPath | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
    } else {
        Write-Host "[X] Config file NOT FOUND: $configPath" -ForegroundColor Red
        Write-Host "" 
        Write-Host "If you are using a token-based tunnel, create: $TokenFilePath" -ForegroundColor Yellow
        Write-Host "Or set env var: QWEN_CF_TUNNEL_TOKEN" -ForegroundColor Yellow
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

    Write-Host ""

    # Check Docker tunnel container
    $containerId = Get-DockerTunnelStatus
    if ($containerId -eq $null) {
        Write-Host "[!] Docker tunnel: Docker not available" -ForegroundColor Yellow
    } elseif ($containerId) {
        Write-Host "[OK] Docker tunnel container running:" -ForegroundColor Green
        Write-Host "  Name: $(Get-DockerTunnelContainerName)" -ForegroundColor Gray
        Write-Host "  ID:   $containerId" -ForegroundColor Gray
    } else {
        Write-Host "[X] Docker tunnel container not running" -ForegroundColor Red
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

    $token = Get-CloudflareTunnelToken
    if ($token) {
        if (-not (Test-DockerInstalled)) {
            Write-Host "[X] Docker not available, but a tunnel token is configured." -ForegroundColor Red
            Write-Host "Install/Start Docker Desktop, or run cloudflared natively." -ForegroundColor Yellow
            return
        }

        $name = Get-DockerTunnelContainerName
        $existing = Get-DockerTunnelStatus
        if ($existing) {
            Write-Host "[!] Docker tunnel already running (container: $name)" -ForegroundColor Yellow
            Write-Host "  View logs: docker logs -f $name" -ForegroundColor Gray
            return
        }

        # Check if API is running
        $port8000 = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue
        if (-not $port8000) {
            Write-Host "[!] WARNING: API Server not detected on port 8000" -ForegroundColor Yellow
            Write-Host "  The tunnel can connect, but requests will fail until the API is up." -ForegroundColor Yellow
        }

        Write-Host "Starting token-based tunnel via Docker container..." -ForegroundColor Cyan
        Write-Host "  Origin: http://host.docker.internal:8000" -ForegroundColor Gray
        
        # Ensure any stale container is removed
        & docker rm -f $name 2>$null | Out-Null

        # Start in detached mode
        $containerId = & docker run -d --rm --name $name cloudflare/cloudflared:latest tunnel --no-autoupdate run --token $token 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[X] Failed to start Docker tunnel" -ForegroundColor Red
            Write-Host "  $containerId" -ForegroundColor Gray
            return
        }

        Write-Host "[OK] Docker tunnel started" -ForegroundColor Green
        Write-Host "  Container: $name" -ForegroundColor Gray
        Write-Host "  Logs:      docker logs -f $name" -ForegroundColor Gray
        return
    }
    
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

    # Stop Docker tunnel container (if present)
    $name = Get-DockerTunnelContainerName
    if (Test-DockerInstalled) {
        & docker rm -f $name 2>$null | Out-Null
    }
    
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
