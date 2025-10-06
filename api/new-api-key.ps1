# Generate New API Key and Restart API Server
# Usage: .\new-api-key.ps1

Write-Host ""
Write-Host "Generating new API key..." -ForegroundColor Cyan
Write-Host ""

& "$PSScriptRoot\manage-key.ps1" -Generate

Write-Host ""
Write-Host "Waiting for key file to be written..." -ForegroundColor Gray
Start-Sleep -Seconds 1

Write-Host "Restarting API server to apply new key..." -ForegroundColor Yellow

# Find and stop the running API server (python process running main.py on port 8000)
$apiProcess = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue | 
    Select-Object -ExpandProperty OwningProcess -ErrorAction SilentlyContinue |
    Get-Process -ErrorAction SilentlyContinue |
    Where-Object { $_.ProcessName -eq "python" }

if ($apiProcess) {
    Write-Host "Stopping API server (PID: $($apiProcess.Id))..." -ForegroundColor Yellow
    Stop-Process -Id $apiProcess.Id -Force
    Start-Sleep -Seconds 2
    Write-Host "API server stopped." -ForegroundColor Green
} else {
    Write-Host "No API server found running on port 8000." -ForegroundColor Gray
}

# Restart the API server
Write-Host "Starting API server with new key..." -ForegroundColor Cyan

# Check if we're in the api directory
$apiDir = $PSScriptRoot
$projectRoot = Split-Path -Parent $apiDir

# Start the server in a new window
$activateScript = "$projectRoot\.venv\Scripts\Activate.ps1"
$startCommand = "cd '$apiDir'; & '$activateScript'; python main.py"
Start-Process powershell -ArgumentList "-NoExit", "-Command", $startCommand -WindowStyle Normal

Write-Host "Waiting for server to start..." -ForegroundColor Gray
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "New API key generated and server restarted!" -ForegroundColor Green
Write-Host "The server should be available in a few seconds at: http://localhost:8000" -ForegroundColor Cyan
Write-Host 'Swagger UI: http://localhost:8000/docs' -ForegroundColor Cyan
Write-Host ""
