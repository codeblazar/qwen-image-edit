# Nunchaku Installation Script
# Run this AFTER Visual Studio Build Tools is installed

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Nunchaku Installation for RTX 4090" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Step 1: Verify VS Build Tools is installed
Write-Host "Step 1: Verifying Visual Studio Build Tools..." -ForegroundColor Yellow

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vswhere) {
    $vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    
    if ($vsPath) {
        Write-Host "[OK] Found Visual Studio Build Tools at: $vsPath" -ForegroundColor Green
        
        # Set up VS environment
        $vcvarsPath = Join-Path $vsPath "VC\Auxiliary\Build\vcvars64.bat"
        if (Test-Path $vcvarsPath) {
            Write-Host "[OK] Found vcvars64.bat" -ForegroundColor Green
        } else {
            Write-Host "[WARNING] Could not find vcvars64.bat" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[ERROR] Visual Studio Build Tools not found!" -ForegroundColor Red
        Write-Host "Please install Visual Studio Build Tools first." -ForegroundColor Red
        Write-Host "Run: .\install-vs-buildtools-guide.ps1" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "[ERROR] Visual Studio Installer not found!" -ForegroundColor Red
    Write-Host "Please install Visual Studio Build Tools first." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 2: Setting up environment for compilation..." -ForegroundColor Yellow

# Import VS environment variables
Push-Location "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build"
cmd /c "vcvars64.bat&set" | ForEach-Object {
    if ($_ -match "=") {
        $v = $_.split("=", 2)
        [System.Environment]::SetEnvironmentVariable($v[0], $v[1])
    }
}
Pop-Location

Write-Host "[OK] Visual Studio environment configured" -ForegroundColor Green

# Verify cl.exe is available
$cl = Get-Command cl.exe -ErrorAction SilentlyContinue
if ($cl) {
    Write-Host "[OK] MSVC compiler (cl.exe) found: $($cl.Path)" -ForegroundColor Green
} else {
    Write-Host "[ERROR] MSVC compiler (cl.exe) not found in PATH!" -ForegroundColor Red
    Write-Host "Try running this in 'Developer Command Prompt for VS 2022' instead." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Step 3: Setting CUDA architecture for RTX 4090..." -ForegroundColor Yellow
$env:TORCH_CUDA_ARCH_LIST = "8.9"
$env:DISTUTILS_USE_SDK = "1"
$env:TORCH_CUDA_VERSION_CHECK = "0"
Write-Host "[OK] TORCH_CUDA_ARCH_LIST = 8.9 (sm_89)" -ForegroundColor Green
Write-Host "[OK] DISTUTILS_USE_SDK = 1" -ForegroundColor Green
Write-Host "[OK] TORCH_CUDA_VERSION_CHECK = 0 (bypassing CUDA version check)" -ForegroundColor Green

Write-Host ""
Write-Host "Step 4: Installing nunchaku from source..." -ForegroundColor Yellow
Write-Host "This will take 10-15 minutes. Please be patient..." -ForegroundColor Yellow
Write-Host ""

# Run pip install with environment variables inherited
$env:TORCH_CUDA_ARCH_LIST = "8.9"
$env:DISTUTILS_USE_SDK = "1"
$env:TORCH_CUDA_VERSION_CHECK = "0"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& "$scriptDir\.venv\Scripts\pip.exe" install --no-build-isolation git+https://github.com/nunchaku-tech/nunchaku.git

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Installation Successful!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Verifying installation..." -ForegroundColor Yellow
    
    & "$scriptDir\.venv\Scripts\python.exe" -c "from nunchaku import NunchakuQwenImageTransformer2DModel; print('Nunchaku imported successfully!')"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "[SUCCESS] Nunchaku is ready to use!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next step: Run the image generation script:" -ForegroundColor Yellow
        Write-Host "  .\run-qwen-image-edit.ps1" -ForegroundColor Cyan
        Write-Host ""
    } else {
        Write-Host "[WARNING] Import test failed, but package may be installed" -ForegroundColor Yellow
    }
} else {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Installation Failed" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Please check the error messages above." -ForegroundColor Red
    Write-Host "Common issues:" -ForegroundColor Yellow
    Write-Host "  1. CUDA version mismatch - see INSTALL_NUNCHAKU.md for workaround" -ForegroundColor Gray
    Write-Host "  2. Missing C++ components - verify VS Build Tools installation" -ForegroundColor Gray
    Write-Host "  3. Out of disk space - ensure you have 5+ GB free" -ForegroundColor Gray
    Write-Host ""
}
