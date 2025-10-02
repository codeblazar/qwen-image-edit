@echo off
REM Nunchaku Installation Script for Windows
echo ========================================
echo   Nunchaku Installation for RTX 4090
echo ========================================
echo.

REM Set up VS Build Tools environment
echo Setting up Visual Studio environment...
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"

REM Set environment variables for CUDA compilation
echo Setting CUDA compilation variables...
set TORCH_CUDA_ARCH_LIST=8.9
set DISTUTILS_USE_SDK=1
set TORCH_CUDA_VERSION_CHECK=0

echo TORCH_CUDA_ARCH_LIST = %TORCH_CUDA_ARCH_LIST%
echo DISTUTILS_USE_SDK = %DISTUTILS_USE_SDK%
echo TORCH_CUDA_VERSION_CHECK = %TORCH_CUDA_VERSION_CHECK%
echo.

echo Installing nunchaku from source (this will take 10-15 minutes)...
echo.

C:\Projects\qwen-image-edit\.venv\Scripts\pip.exe install --no-build-isolation git+https://github.com/nunchaku-tech/nunchaku.git

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo   Installation Successful!
    echo ========================================
    echo.
    echo Verifying installation...
    C:\Projects\qwen-image-edit\.venv\Scripts\python.exe -c "from nunchaku import NunchakuQwenImageTransformer2DModel; print('Nunchaku imported successfully!')"
) else (
    echo.
    echo ========================================
    echo   Installation Failed
    echo ========================================
    echo.
    echo Please check the error messages above.
)

pause
