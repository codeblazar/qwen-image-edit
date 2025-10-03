# Quick Start Script for Qwen Image Edit API
# Run this from the main project directory

Write-Host "🚀 Starting Qwen Image Edit API..." -ForegroundColor Cyan
Write-Host ""

# Check if virtual environment is activated
if (-not $env:VIRTUAL_ENV) {
    Write-Host "⚠️  Virtual environment not activated. Activating..." -ForegroundColor Yellow
    .\.venv\Scripts\Activate.ps1
}

# Check if FastAPI dependencies are installed
Write-Host "📦 Checking dependencies..." -ForegroundColor Cyan
$pipList = pip list 2>$null
if ($pipList -notmatch "fastapi") {
    Write-Host "📥 Installing API dependencies..." -ForegroundColor Yellow
    pip install -r api/requirements.txt
} else {
    Write-Host "✅ Dependencies already installed" -ForegroundColor Green
}

Write-Host ""
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "🌟 API SERVER STARTING" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""
Write-Host "📍 Swagger UI:  http://localhost:8000/docs" -ForegroundColor Yellow
Write-Host "📍 ReDoc:       http://localhost:8000/redoc" -ForegroundColor Yellow
Write-Host "📍 API Root:    http://localhost:8000/" -ForegroundColor Yellow
Write-Host ""
Write-Host "💡 Press Ctrl+C to stop the server" -ForegroundColor Gray
Write-Host ""

# Change to api directory and start server
Set-Location api
python main.py
