# Qwen Image Edit - Launcher Script

if (-not $env:VIRTUAL_ENV) {
    Write-Host "Activating venv..." -ForegroundColor Cyan
    & .\.venv\Scripts\Activate.ps1
}

function Stop-QwenProcesses {
    $port8000 = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue
    if ($port8000) {
        Stop-Process -Id $port8000.OwningProcess -Force -ErrorAction SilentlyContinue
    }
    $port7860 = Get-NetTCPConnection -LocalPort 7860 -ErrorAction SilentlyContinue
    if ($port7860) {
        Stop-Process -Id $port7860.OwningProcess -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "QWEN IMAGE EDIT - LAUNCHER" -ForegroundColor Green
Write-Host ""
Write-Host "[1] API Server (port 8000)" -ForegroundColor White
Write-Host "[2] Gradio UI (port 7860)" -ForegroundColor White
Write-Host "[Q] Quit" -ForegroundColor White
Write-Host ""
$choice = Read-Host "Choice (1/2/Q)"

switch ($choice.ToUpper()) {
    "1" {
        Stop-QwenProcesses
        
        # Check if API key file exists, if not create one
        $keyFile = "$PSScriptRoot\api\.api_key"
        if (-not (Test-Path $keyFile)) {
            Write-Host "No API key found. Running manage-key.ps1..." -ForegroundColor Yellow
            & "$PSScriptRoot\api\manage-key.ps1" -Generate
        }
        
        # Read the API key
        $apiKey = Get-Content $keyFile -Raw
        
        $apiCmd = "Set-Location '$PWD\api'; python main.py"
        Start-Process powershell -ArgumentList "-NoExit","-Command",$apiCmd -WindowStyle Minimized
        Start-Sleep 5
        Write-Host ""
        Write-Host "API RUNNING: http://localhost:8000/docs" -ForegroundColor Green
        Write-Host "API Key: $apiKey" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To rotate the key, run: .\api\manage-key.ps1 -Rotate" -ForegroundColor Gray
    }
    "2" {
        Stop-QwenProcesses
        $gradioCmd = "Set-Location '$PWD'; python qwen_gradio_ui.py"
        Start-Process powershell -ArgumentList "-NoExit","-Command",$gradioCmd
        Start-Sleep 5
        Write-Host ""
        Write-Host "GRADIO RUNNING: http://localhost:7860" -ForegroundColor Green
    }
    "Q" { exit }
}