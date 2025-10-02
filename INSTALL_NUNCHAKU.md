# Installing Nunchaku from Source on Windows

## Current Issue
Nunchaku requires compilation from source, but the build is failing due to:
1. Missing MSVC C++ compiler (`cl.exe`)
2. CUDA version mismatch (System: 13.0, PyTorch: 12.1)

## Solution: Install Visual Studio Build Tools

### Step 1: Install Visual Studio 2022 Build Tools

1. Download Visual Studio 2022 Build Tools:
   https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022

2. Run the installer and select:
   - ✅ **Desktop development with C++**
   - Under "Individual components", ensure these are checked:
     - MSVC v143 - VS 2022 C++ x64/x86 build tools
     - Windows 10/11 SDK
     - C++ CMake tools for Windows

3. Install (this will take 5-10 minutes)

### Step 2: Set up Environment Variables

After Visual Studio Build Tools installation, you need to run commands in a **Developer Command Prompt** OR set up the environment in PowerShell:

#### Option A: Use Developer Command Prompt (Easier)
1. Search for "Developer Command Prompt for VS 2022" in Start Menu
2. Navigate to project: `cd C:\Projects\qwen-image-edit`
3. Activate venv: `.\.venv\Scripts\Activate.ps1`
4. Install nunchaku:
```
$env:TORCH_CUDA_ARCH_LIST='8.9'
pip install --no-build-isolation git+https://github.com/nunchaku-tech/nunchaku.git
```

#### Option B: Set up VS Environment in PowerShell
```powershell
# Add VS to PATH
& "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\Launch-VsDevShell.ps1" -Arch amd64 -HostArch amd64

# Then install nunchaku
cd C:\Projects\qwen-image-edit
.\.venv\Scripts\Activate.ps1
$env:TORCH_CUDA_ARCH_LIST='8.9'
pip install --no-build-isolation git+https://github.com/nunchaku-tech/nunchaku.git
```

### Step 3: Handle CUDA Version Mismatch

The CUDA version check in PyTorch is strict. If the build still fails with CUDA mismatch, you have two options:

#### Option 1: Reinstall PyTorch with CUDA 11.8 (more compatible)
```powershell
pip uninstall torch torchvision torchaudio -y
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
```

#### Option 2: Patch PyTorch's version check (advanced)
Edit: `C:\Projects\qwen-image-edit\.venv\Lib\site-packages\torch\utils\cpp_extension.py`

Find line ~415 with:
```python
raise RuntimeError(CUDA_MISMATCH_MESSAGE.format(cuda_str_version, torch.version.cuda))
```

Change to:
```python
# raise RuntimeError(CUDA_MISMATCH_MESSAGE.format(cuda_str_version, torch.version.cuda))
pass  # Allow CUDA version mismatch
```

### Step 4: Build and Install (Expected time: 10-15 minutes)

```powershell
cd C:\Projects\qwen-image-edit
.\.venv\Scripts\Activate.ps1
$env:TORCH_CUDA_ARCH_LIST='8.9'
pip install --no-build-isolation git+https://github.com/nunchaku-tech/nunchaku.git
```

Watch for successful compilation messages. The build compiles CUDA kernels which takes time.

### Step 5: Verify Installation

```powershell
python -c "from nunchaku import NunchakuQwenImageTransformer2DModel; print('Success!')"
```

## Alternative: Use ComfyUI

If compilation continues to fail, consider using ComfyUI with the nunchaku plugin:
1. Install ComfyUI: https://github.com/comfyanonymous/ComfyUI
2. Install ComfyUI-nunchaku: https://github.com/nunchaku-tech/ComfyUI-nunchaku
3. This provides a pre-built solution without compilation

## Estimated Timeline

- Visual Studio Build Tools installation: 10-15 minutes
- Nunchaku compilation: 10-15 minutes
- Total: ~25-30 minutes

## What Happens After Successful Installation

Once nunchaku is installed, you can run:
```powershell
python qwen_image_edit_nunchaku.py
```

This will:
1. Download the quantized model (~12.7 GB) on first run
2. Process the images
3. Generate output: `output_image_edit_plus_r128.png`

## Need Help?

- Check CUDA is detected: `nvcc --version`
- Check MSVC is in PATH: `cl.exe` (should show version info)
- Check Python can see CUDA: `python -c "import torch; print(torch.cuda.is_available())"`
