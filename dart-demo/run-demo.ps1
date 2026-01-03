param(
    [string]$ApiBase = "https://qwen.codeblazar.org/api/v1",
    [string]$Instruction = "Change the model's hair style to short",
    [string]$Out = ".\\edited.png",
    [string]$SeedImage = ".\\seed.png"
)

$ErrorActionPreference = "Stop"

# Ensure we're running from dart-demo
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

if (-not (Get-Command dart -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Dart SDK not found on PATH. Install Dart/Flutter and retry." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $SeedImage)) {
    Write-Host "[ERROR] Seed image not found: $SeedImage" -ForegroundColor Red
    exit 1
}

$keyPath = Join-Path $scriptDir "..\\api\\.api_key"
if (-not (Test-Path $keyPath)) {
    Write-Host "[ERROR] API key file not found: $keyPath" -ForegroundColor Red
    Write-Host "Start the API once (it will generate a key) or run api\\manage-key.ps1." -ForegroundColor Yellow
    exit 1
}

$env:QWEN_API_KEY = (Get-Content $keyPath -Raw).Trim()
if (-not $env:QWEN_API_KEY) {
    Write-Host "[ERROR] API key file is empty: $keyPath" -ForegroundColor Red
    exit 1
}

# Optional: ensure dependencies are present (fast no-op if already done)
dart pub get | Out-Null

Write-Host "Running Dart demo..." -ForegroundColor Cyan
Write-Host "  API:  $ApiBase" -ForegroundColor Gray
Write-Host "  In:   $SeedImage" -ForegroundColor Gray
Write-Host "  Out:  $Out" -ForegroundColor Gray

& dart run bin\qwen_api_demo.dart `
  --api-base $ApiBase `
  --image $SeedImage `
  --instruction $Instruction `
  --out $Out
