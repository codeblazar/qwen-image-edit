# Nunchaku Installation Script with PyTorch CUDA Check Patch
# This patches PyTorch to bypass the CUDA version mismatch check

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Nunchaku Installation (Patched)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check if we're in venv
$pythonPath = (python -c "import sys; print(sys.executable)" 2>&1)
if ($pythonPath -notlike "*\.venv\*") {
    Write-Host "[ERROR] Not in virtual environment!" -ForegroundColor Red
    Write-Host "Please run: .\.venv\Scripts\Activate.ps1" -ForegroundColor Yellow
    Write-Host "Then run this script again." -ForegroundColor Yellow
    exit 1
}
Write-Host "[OK] Virtual environment active" -ForegroundColor Green

# Step 1: Patch PyTorch to skip CUDA version check
Write-Host "`nStep 1: Patching PyTorch to bypass CUDA version check..." -ForegroundColor Yellow
$patchFile = ".\.venv\Lib\site-packages\torch\utils\cpp_extension.py"

if (Test-Path $patchFile) {
    # Read the file
    $content = Get-Content $patchFile -Raw
    
    # Check if already patched
    if ($content -match '# raise RuntimeError\(CUDA_MISMATCH_MESSAGE') {
        Write-Host "[OK] PyTorch already patched" -ForegroundColor Green
    } else {
        # Patch: comment out the RuntimeError line
        $content = $content -replace 'raise RuntimeError\(CUDA_MISMATCH_MESSAGE', '# raise RuntimeError(CUDA_MISMATCH_MESSAGE'
        $content | Set-Content $patchFile -NoNewline
        Write-Host "[OK] PyTorch patched successfully" -ForegroundColor Green
    }
} else {
    Write-Host "[ERROR] Could not find PyTorch cpp_extension.py" -ForegroundColor Red
    exit 1
}

# Step 2: Set up VS Build Tools environment
Write-Host "`nStep 2: Setting up Visual Studio environment..." -ForegroundColor Yellow

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vswhere) {
    $vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    
    if ($vsPath) {
        Write-Host "[OK] Found Visual Studio Build Tools" -ForegroundColor Green
        
        # Import VS environment variables
        Push-Location "$vsPath\VC\Auxiliary\Build"
        cmd /c "vcvars64.bat&set" | ForEach-Object {
            if ($_ -match "=") {
                $v = $_.split("=", 2)
                Set-Item -Force -Path "ENV:\$($v[0])" -Value "$($v[1])"
            }
        }
        Pop-Location
        Write-Host "[OK] Visual Studio environment configured" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Visual Studio Build Tools not found!" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[ERROR] vswhere.exe not found!" -ForegroundColor Red
    exit 1
}

# Step 3: Set environment variables
Write-Host "`nStep 3: Setting CUDA compilation variables..." -ForegroundColor Yellow
$env:TORCH_CUDA_ARCH_LIST = "8.9"
$env:DISTUTILS_USE_SDK = "1"
Write-Host "[OK] TORCH_CUDA_ARCH_LIST = 8.9 (sm_89)" -ForegroundColor Green
Write-Host "[OK] DISTUTILS_USE_SDK = 1" -ForegroundColor Green

# Step 4: Clone and install nunchaku from source
Write-Host "`nStep 4: Cloning nunchaku repository..." -ForegroundColor Yellow
$tempDir = $env:TEMP
$nunchakuDir = Join-Path $tempDir "nunchaku"

# Remove old clone if exists
if (Test-Path $nunchakuDir) {
    Write-Host "Removing old nunchaku directory..." -ForegroundColor Gray
    Remove-Item -Recurse -Force $nunchakuDir
}

# Clone repository
Write-Host "Cloning from GitHub..." -ForegroundColor Yellow
git clone https://github.com/nunchaku-tech/nunchaku.git $nunchakuDir

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to clone repository!" -ForegroundColor Red
    exit 1
}

# Initialize submodules (CRITICAL - missing spdlog headers without this!)
Write-Host "`nStep 5: Initializing git submodules..." -ForegroundColor Yellow
Push-Location $nunchakuDir
git submodule update --init --recursive

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to initialize submodules!" -ForegroundColor Red
    Pop-Location
    exit 1
}
Write-Host "[OK] Submodules initialized" -ForegroundColor Green

# Install from local directory
Write-Host "`nStep 6: Installing nunchaku from source..." -ForegroundColor Yellow
Write-Host "This will take 10-15 minutes. Please be patient...`n" -ForegroundColor Yellow

pip install -e . --no-build-isolation
$installResult = $LASTEXITCODE
Pop-Location

if ($installResult -eq 0) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Installation Successful!" -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    Write-Host "Verifying installation..." -ForegroundColor Yellow
    python -c "from nunchaku import NunchakuQwenImageTransformer2DModel; print('✓ Nunchaku imported successfully!')"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n[SUCCESS] Nunchaku is ready to use!" -ForegroundColor Green
        Write-Host "`nNext step: Run the image generation script:" -ForegroundColor Yellow
        Write-Host "  python qwen_image_edit_nunchaku.py`n" -ForegroundColor Cyan
    }
} else {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Installation Failed" -ForegroundColor Red
    Write-Host "========================================`n" -ForegroundColor Cyan
    Write-Host "Please check the error messages above." -ForegroundColor Red
}
