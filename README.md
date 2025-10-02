# Qwen Image Edit 2509

AI-powered multi-image editing using Qwen's Image Edit model with quantized transformers for 24GB VRAM GPUs.

## ⚠️ CRITICAL: READ THIS FIRST

### 🚫 Three Common Mistakes That Will Waste Hours

1. **❌ WRONG MODEL**: Do NOT use `Qwen/Qwen-Image-Edit-2509` (40GB full model)
   - ✅ USE: `nunchaku-tech/nunchaku-qwen-image-edit-2509` (12.7GB quantized)
   - The 40GB model **WILL NOT FIT** on RTX 4090 24GB VRAM
   - You will get OOM (Out of Memory) errors

2. **❌ WRONG NUNCHAKU**: Do NOT use `pip install nunchaku` (0.15.4 stats package)
   - ✅ USE: Install from source (see below)
   - The PyPI package "nunchaku" is a completely different stats library
   - You need `nunchaku==1.0.1+torch2.5` for AI model quantization

3. **❌ NOT USING VENV**: Do NOT install in system Python
   - ✅ ALWAYS activate `.venv` before running ANY command
   - Check prompt shows `(.venv)` at the start
   - If you see errors, you're probably not in the venv

## 🎯 Overview

This project implements the Qwen Image Edit 2509 model using quantized INT4 transformers via nunchaku, enabling high-quality multi-image AI editing on consumer GPUs like the RTX 4090 (24GB VRAM).

## ✨ Features

- **Quantized Model Support**: Uses INT4 quantization (rank 128) to fit in 24GB VRAM
- **Multi-Image Editing**: Combine and edit multiple images with AI guidance
- **High Quality Output**: ~12.7GB quantized model maintains excellent quality
- **CUDA-Optimized**: Built for NVIDIA GPUs with Compute Capability 8.9 (RTX 4090)

## 🖼️ Example

**Prompt**: "The magician bear is on the left, the alchemist bear is on the right, facing each other in the central park square."

**Generated Image**: `output_image_edit_plus_r128.png`
- **Inference Time**: 2:44 (40 steps)
- **Model Size**: 12.7GB quantized
- **VRAM Usage**: ~23GB

## 🛠️ System Requirements

### Hardware
- **GPU**: NVIDIA GeForce RTX 4090 (24GB VRAM) or similar
- **VRAM**: 24GB minimum
- **Disk Space**: ~50GB for models and dependencies
- **RAM**: 32GB recommended
- **Compute Capability**: 8.9 (sm_89)

### Software
- **OS**: Windows 10/11
- **Python**: 3.10.6
- **CUDA**: 13.0 (or 12.1+)
- **Driver**: 581.29 or newer
- **Visual Studio Build Tools 2022**: With C++ components

## 📦 Installation

### Step 1: Create Virtual Environment

**⚠️ CRITICAL: You MUST use a virtual environment!**

```powershell
# Navigate to project directory
cd C:\Projects\qwen-image-edit

# Create virtual environment
python -m venv .venv

# Activate it (DO THIS EVERY TIME)
.\.venv\Scripts\Activate.ps1

# Verify activation - you should see (.venv) in your prompt
# Your prompt should look like: (.venv) PS C:\Projects\qwen-image-edit>
```

### Step 2: Install PyTorch with CUDA

```powershell
# MAKE SURE (.venv) is showing in your prompt!
pip install torch==2.5.1+cu121 torchvision==0.20.1+cu121 torchaudio==2.5.1+cu121 --index-url https://download.pytorch.org/whl/cu121
```

### Step 3: Install Diffusers from GitHub

**⚠️ Must be from GitHub for QwenImageEditPlusPipeline support**

```powershell
# MAKE SURE (.venv) is showing in your prompt!
pip install git+https://github.com/huggingface/diffusers.git
```

### Step 4: Install Other Dependencies

```powershell
# MAKE SURE (.venv) is showing in your prompt!
pip install -r requirements.txt
```

### Step 5: Install nunchaku from Source

**⚠️ DO NOT use `pip install nunchaku` - that's a different package!**

See [INSTALL_NUNCHAKU.md](INSTALL_NUNCHAKU.md) for complete instructions.

**Quick version:**
```powershell
# MAKE SURE (.venv) is showing in your prompt!

# Install Visual Studio Build Tools 2022 first (if not already installed)
# Download from: https://visualstudio.microsoft.com/downloads/

# Clone and build nunchaku
cd $env:TEMP
git clone https://github.com/nunchaku-tech/nunchaku.git
cd nunchaku
git submodule update --init --recursive
$env:TORCH_CUDA_ARCH_LIST="8.9"
$env:DISTUTILS_USE_SDK="1"
pip install -e . --no-build-isolation

# Return to project
cd C:\Projects\qwen-image-edit
```

**Verify nunchaku installation:**
```powershell
# Should show: nunchaku==1.0.1+torch2.5 (NOT 0.15.4!)
pip show nunchaku
```

### Step 6: Run Prerequisites Check

```powershell
# MAKE SURE (.venv) is showing in your prompt!
.\check.ps1
```

## 🚀 Quick Start

**⚠️ ALWAYS activate venv first!**

```powershell
# Navigate to project
cd C:\Projects\qwen-image-edit

# Activate virtual environment (DO THIS EVERY TIME!)
.\.venv\Scripts\Activate.ps1

# Verify you see (.venv) in your prompt
# Prompt should show: (.venv) PS C:\Projects\qwen-image-edit>

# Run image generation
python qwen_image_edit_nunchaku.py
```

The script will:
1. Download the quantized model (~12.7GB) on first run
2. Download sample images from Qwen examples
3. Generate an edited image combining both inputs
4. Save output to `generated-images/output_r128_YYYYMMDD_HHMMSS.png`

**Generation Time**: ~2-3 minutes after model is downloaded

**Output**: All generated images are saved in the `generated-images/` folder with timestamps to prevent overwriting.

## 📊 Performance

- **First Run**: ~5 minutes (model download + generation)
- **Subsequent Runs**: ~2-3 minutes (generation only)
- **VRAM Usage**: ~23GB during inference
- **Model Download Size**: 12.7GB quantized model
- **Inference Steps**: 40 (adjustable: 20-50)

## 📁 Project Structure

```
qwen-image-edit/
├── .venv/                          # Virtual environment (do not commit)
├── generated-images/               # Generated images output folder
├── qwen_image_edit_nunchaku.py    # Main script
├── check.ps1                       # Prerequisites checker
├── install-nunchaku-patched.ps1   # Installation helper
├── requirements.txt                # Python dependencies
├── README.md                       # This file
├── TODO.txt                        # TODO list and improvements
└── .gitignore                      # Git ignore rules
```

## 🔧 Model Options

### ✅ Quantized Models (THE ONLY MODELS THAT WORK on RTX 4090)

**⚠️ IMPORTANT: Only use models from `nunchaku-tech/nunchaku-qwen-image-edit-2509`**

**Standard Models (40 steps):**
- `svdq-int4_r32` (11.5 GB) - Good quality
- `svdq-int4_r128` (12.7 GB) ⭐ **Best Quality** ← **WE USE THIS ONE**

**Lightning Models (8 steps - Faster):**
- `svdq-int4_r32-lightningv2.0-8steps` - Fast
- `svdq-int4_r128-lightningv2.0-8steps` ⭐ **Best Balance** - Fast + Quality

**Lightning Models (4 steps - Fastest):**
- `svdq-int4_r32-lightningv2.0-4steps` - Very fast
- `svdq-int4_r128-lightningv2.0-4steps` - Very fast + Better quality

**Current script uses:** `nunchaku-tech/nunchaku-qwen-image-edit-2509/svdq-int4_r128`

### ❌ DO NOT USE: Full Model (Will Crash!)

**🚫 `Qwen/Qwen-Image-Edit-2509` (~40GB) - DO NOT USE!**

This is the WRONG model. It will:
- ❌ Cause OOM (Out of Memory) errors
- ❌ Crash your system
- ❌ NOT fit on RTX 4090 24GB VRAM
- ❌ Waste hours of your time downloading it

**IF YOU SEE THIS IN YOUR CODE, YOU'RE USING THE WRONG MODEL:**
```python
# ❌ WRONG - DO NOT USE
pipeline = QwenImageEditPlusPipeline.from_pretrained("Qwen/Qwen-Image-Edit-2509")
```

**✅ CORRECT - USE THIS:**
```python
# ✅ CORRECT - Load quantized transformer first
transformer = NunchakuQwenImageTransformer2DModel.from_pretrained(
    "nunchaku-tech/nunchaku-qwen-image-edit-2509/svdq-int4_r128-qwen-image-edit-2509.safetensors"
)
pipeline = QwenImageEditPlusPipeline.from_pretrained(
    "Qwen/Qwen-Image-Edit-2509",  # Pipeline config only
    transformer=transformer  # Use quantized transformer
)
```

## � How to Verify Everything is Correct

### ✅ Check 1: Virtual Environment is Active

```powershell
# Your prompt should look like this:
# (.venv) PS C:\Projects\qwen-image-edit>

# If it doesn't, activate venv:
.\.venv\Scripts\Activate.ps1
```

### ✅ Check 2: Correct nunchaku Version

```powershell
# MAKE SURE (.venv) is showing in your prompt!
pip show nunchaku

# Should show:
# Name: nunchaku
# Version: 1.0.1+torch2.5
# Location: C:\Users\...\AppData\Local\Temp\nunchaku

# ❌ If it shows Version: 0.15.4 - YOU HAVE THE WRONG PACKAGE!
# Fix: pip uninstall nunchaku -y
# Then follow nunchaku installation steps above
```

### ✅ Check 3: Correct Model in Code

```powershell
# Check your script uses quantized models
Get-Content qwen_image_edit_nunchaku.py | Select-String "nunchaku-tech"

# Should show:
# "nunchaku-tech/nunchaku-qwen-image-edit-2509/svdq-..."

# ❌ If it shows only "Qwen/Qwen-Image-Edit-2509" without nunchaku-tech
# YOU'RE USING THE WRONG 40GB MODEL!
```

### ✅ Check 4: All Dependencies Installed

```powershell
# MAKE SURE (.venv) is showing in your prompt!
.\check.ps1

# Should show all ✓ checks passing
```

## 🛠️ Detailed Installation Guide

See [INSTALL_NUNCHAKU.md](INSTALL_NUNCHAKU.md) for complete step-by-step instructions including:
- Visual Studio Build Tools setup
- PyTorch CUDA patch (if needed)
- Nunchaku compilation from source
- Troubleshooting common issues

## ⚠️ Known Issues

1. **Xet Storage Warning**: Install `hf_xet` for faster downloads:
   ```powershell
   pip install hf_xet
   ```

2. **CUDA Version Mismatch**: PyTorch compiled with CUDA 12.1 but system has CUDA 13.0
   - **Solution**: Applied patch to skip version check (see INSTALL_NUNCHAKU.md)

3. **torch_dtype Deprecation**: Minor deprecation warning
   - **Impact**: None, will be fixed in future update

4. **Config Attributes Warning**: Benign warning about `pooled_projection_dim`
   - **Impact**: None, can be ignored

## 🙏 Credits

- **Model**: [Qwen Image Edit 2509](https://huggingface.co/Qwen/Qwen-Image-Edit-2509) by Alibaba Cloud
- **Quantization**: [nunchaku](https://github.com/nunchaku-tech/nunchaku) by nunchaku-tech
- **Diffusers**: [Hugging Face Diffusers](https://github.com/huggingface/diffusers)

## 📝 License

This project uses models and libraries with their respective licenses. Please check individual component licenses before commercial use.

## 🤝 Contributing

Contributions welcome! Please see [TODO.txt](TODO.txt) for current improvement ideas.

### For Developers: Check for Absolute Paths

Before committing changes, ensure no absolute paths exist:

```powershell
# Check all Python and PowerShell files for absolute paths
Get-ChildItem -Recurse -Include *.py,*.ps1,*.md | Select-String -Pattern "C:\\"
```

## 🐛 Troubleshooting

### ❌ Issue: "ModuleNotFoundError: No module named 'nunchaku'"

**Cause**: One of two problems:
1. Not in virtual environment
2. Wrong nunchaku installed (stats package)

**Solution**:
```powershell
# 1. Activate venv (look for (.venv) in prompt)
.\.venv\Scripts\Activate.ps1

# 2. Check nunchaku version
pip show nunchaku

# If version is 0.15.4 - WRONG PACKAGE!
pip uninstall nunchaku -y

# Install correct nunchaku from source
# See INSTALL_NUNCHAKU.md for full instructions
```

### ❌ Issue: "CUDA out of memory"

**Cause**: One of three problems:
1. Using wrong 40GB full model
2. Not enough VRAM
3. Other apps using GPU

**Solution**:
```powershell
# 1. Check you're using quantized model
Get-Content qwen_image_edit_nunchaku.py | Select-String "nunchaku-tech"
# Should show: nunchaku-tech/nunchaku-qwen-image-edit-2509

# 2. Close other GPU applications
# - Close Chrome/Edge (uses GPU)
# - Close other AI apps
# - Check GPU usage: nvidia-smi

# 3. If still failing, you may be using the wrong 40GB model!
```

### ❌ Issue: Compilation fails during nunchaku installation

**Solution**: Install Visual Studio Build Tools 2022 with C++ components
```powershell
# Download from: https://visualstudio.microsoft.com/downloads/
# Select: "Desktop development with C++"
# See INSTALL_NUNCHAKU.md for detailed instructions
```

### ❌ Issue: Wrong nunchaku package installed (0.15.4 stats package)

**This is the #1 most common mistake!**

**Solution**:
```powershell
# MAKE SURE (.venv) is showing in your prompt!

# Remove wrong package
pip uninstall nunchaku -y

# Install correct version from source
# See INSTALL_NUNCHAKU.md for full instructions
cd $env:TEMP
git clone https://github.com/nunchaku-tech/nunchaku.git
cd nunchaku
git submodule update --init --recursive
pip install -e . --no-build-isolation
```

### ❌ Issue: Script runs but generates garbage/black images

**Cause**: Probably using wrong 40GB model or wrong nunchaku

**Solution**:
```powershell
# Verify BOTH are correct:

# 1. Check nunchaku version (should be 1.0.1+torch2.5)
pip show nunchaku

# 2. Check model in code (should have nunchaku-tech)
Get-Content qwen_image_edit_nunchaku.py | Select-String "nunchaku-tech"
```

### ❌ Issue: Commands fail with "python: command not found"

**Cause**: Not in virtual environment

**Solution**:
```powershell
# Activate venv - look for (.venv) in prompt
.\.venv\Scripts\Activate.ps1

# Verify activation worked
python --version
# Should show: Python 3.10.6
```

---

## 🎯 Final Pre-Flight Checklist

**Before running the script, verify ALL of these:**

- [ ] ✅ Prompt shows `(.venv)` at the start
- [ ] ✅ `pip show nunchaku` shows version `1.0.1+torch2.5` (NOT 0.15.4)
- [ ] ✅ `Get-Content qwen_image_edit_nunchaku.py | Select-String "nunchaku-tech"` shows quantized model path
- [ ] ✅ `.\check.ps1` passes all checks
- [ ] ✅ `nvidia-smi` shows RTX 4090 with 24GB VRAM available
- [ ] ✅ You have ~50GB free disk space for model downloads
- [ ] ✅ No other applications are using significant GPU memory

**If ANY of these are ❌, fix them first before running the script!**

---

## 📚 Quick Reference

**Activate venv (do this EVERY time):**
```powershell
cd C:\Projects\qwen-image-edit
.\.venv\Scripts\Activate.ps1
```

**Run script:**
```powershell
python qwen_image_edit_nunchaku.py
```

**Check nunchaku version:**
```powershell
pip show nunchaku  # Should be 1.0.1+torch2.5
```

**Verify model in code:**
```powershell
Get-Content qwen_image_edit_nunchaku.py | Select-String "nunchaku-tech"
```

---

**Made with ❤️ for AI image editing on consumer GPUs**
