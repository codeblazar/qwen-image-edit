# Qwen Image Edit# Qwen Image Edit 3. **❌ NOT USING VENV**: Do NOT install in system Python

   - ✅ USE: Always activate `.venv` before running ANY command

AI-powered image editing using Qwen's Image Edit 2509 model with quantized INT4 transformers for 24GB VRAM GPUs.   - Check prompt shows `(.venv)` at the start

   - If you see errors, you're probably not in the venv

## ⚠️ CRITICAL: Common Mistakes

4. **❌ WRONG PARAMETERS**: Do NOT assume all models use the same parameters

1. **❌ WRONG MODEL**: Do NOT use `Qwen/Qwen-Image-Edit-2509` (40GB)   - ✅ ALWAYS check the HuggingFace model card for optimal settings

   - ✅ USE: `nunchaku-tech/nunchaku-qwen-image-edit-2509` (12.7GB quantized)   - Lightning/Turbo/distilled models need different `true_cfg_scale` values

      - **Example**: Standard models use `true_cfg_scale=4.0`, Lightning uses `1.0`

2. **❌ WRONG NUNCHAKU**: Do NOT use `pip install nunchaku` (wrong package!)   - Using wrong parameters = poor quality, blocky/pixelated output

   - ✅ USE: Install from source (see [`INSTALL_NUNCHAKU.md`](INSTALL_NUNCHAKU.md))   - See "Model-Specific Parameters" section below

   

3. **❌ NOT USING VENV**: Always activate `.venv` before running commands## 🎯 Overview

   - ✅ Check prompt shows `(.venv)` at the startAI-powered multi-image editing using Qwen's Image Edit model with quantized transformers for 24GB VRAM GPUs.



## 🚀 Quick Start## ⚠️ CRITICAL: READ THIS FIRST



### Option 1: Web UI (Recommended)### 🚫 Three Common Mistakes That Will Waste Hours

```powershell

.\launch.ps1    # Select option 21. **❌ WRONG MODEL**: Do NOT use `Qwen/Qwen-Image-Edit-2509` (40GB full model)

```   - ✅ USE: `nunchaku-tech/nunchaku-qwen-image-edit-2509` (12.7GB quantized)

Access at http://localhost:7860   - The 40GB model **WILL NOT FIT** on RTX 4090 24GB VRAM

   - You will get OOM (Out of Memory) errors

### Option 2: REST API

```powershell2. **❌ WRONG NUNCHAKU**: Do NOT use `pip install nunchaku` (0.15.4 stats package)

.\launch.ps1    # Select option 1   - ✅ USE: Install from source (see below)

```   - The PyPI package "nunchaku" is a completely different stats library

Swagger UI at http://localhost:8000/docs   - You need `nunchaku==1.0.1+torch2.5` for AI model quantization



See [`api/README.md`](api/README.md) for API documentation and test scripts.3. **❌ NOT USING VENV**: Do NOT install in system Python

   - ✅ ALWAYS activate `.venv` before running ANY command

## 📦 Installation   - Check prompt shows `(.venv)` at the start

   - If you see errors, you're probably not in the venv

**Full installation guide:** [`INSTALL_NUNCHAKU.md`](INSTALL_NUNCHAKU.md)

## 🎯 Overview

Quick steps:

1. Create venv: `python -m venv .venv`This project implements the Qwen Image Edit 2509 model - an **MMDiT (Multimodal Diffusion Transformer)** architecture - using quantized INT4 transformers via nunchaku, enabling high-quality AI image editing on consumer GPUs like the RTX 4090 (24GB VRAM).

**Architecture:** MMDiT (Multimodal Diffusion Transformer) - NOT traditional U-Net Stable Diffusion  
**Model Type:** Vision-language transformer for instruction-based image editing  
**Quantization:** INT4 (rank 128) via nunchaku for memory efficiency

2. Activate: `.\.venv\Scripts\Activate.ps1`

3. Install requirements: `pip install -r requirements.txt`**🌟 NEW: Gradio Web UI** - Interactive web interface for easy image editing!

4. Install nunchaku from source (see guide)- `qwen_gradio_ui.py` - **Recommended!** Web interface with multi-model support



## ✨ Features**🚀 NEW: REST API** - Production-ready FastAPI server with queue management!

- See [`api/README.md`](api/README.md) for complete API documentation

- **🎨 Gradio Web UI**: Interactive web interface with multi-model support- Job queue system with concurrent processing

- **🚀 REST API**: Production FastAPI server with job queue- Comprehensive test suite (14 tests, 100% coverage)

- **Multi-Model Support**: 4-step (10s), 8-step (40s), 40-step (3min)- API key authentication with automatic management

- **Face Preservation**: Automatic identity preservation- Cloudflare Tunnel ready for remote access

- **INT4 Quantization**: 12.7GB model fits in 24GB VRAM

- **Queue Management**: Concurrent job processing with overflow protection**Command-line scripts:**

- **Comprehensive Testing**: 14-test suite with 100% API coverage- `qwen_image_edit_nunchaku.py` - Standard 40-step model (best quality, ~2:45)

- `qwen_image_edit_lightning.py` - Lightning 8-step model (fast, ~21s)

## 🖼️ Supported Image Formats- `qwen_image_edit_lightning_4step.py` - Lightning 4-step model (ultra-fast, ~10s)

- `qwen_instruction_edit.py` - Instruction-based single-image editing

- **PNG** (`.png`) - Recommended for transparency

- **JPEG** (`.jpg`, `.jpeg`) - Standard photos## ✨ Features



**API Limitations:** 10MB max, 2048x2048 max dimensions- **🎨 Gradio Web UI**: Easy-to-use web interface with real-time preview

- **🚀 REST API**: Production-ready FastAPI server with job queue (see [`api/README.md`](api/README.md))

## 🛠️ System Requirements- **Multi-Model Support**: Switch between 4-step, 8-step, and 40-step models on-the-fly

- **Random Seeds**: Automatic random seed generation for variety

### Hardware- **Face Preservation**: Strong automatic face identity preservation

- **GPU**: NVIDIA RTX 4090 (24GB VRAM) or similar- **Quantized Model Support**: Uses INT4 quantization (rank 128) to fit in 24GB VRAM

- **RAM**: 32GB recommended- **High Quality Output**: ~12.7GB quantized model maintains excellent quality

- **Disk**: ~50GB for models- **Lightning Fast Option**: 4-step model generates in ~10 seconds!

- **CUDA-Optimized**: Built for NVIDIA GPUs with Compute Capability 8.9 (RTX 4090)

### Software- **Queue Management**: API handles concurrent jobs with automatic queuing

- **OS**: Windows 10/11- **Comprehensive Testing**: 14-test suite validates all functionality

- **Python**: 3.10.6

- **CUDA**: 12.1+ or 13.0## 🖼️ Example

- **Visual Studio Build Tools 2022**: C++ components required

**Prompt**: "The magician bear is on the left, the alchemist bear is on the right, facing each other in the central park square."

## 📁 Project Structure

**Generated Image**: `output_image_edit_plus_r128.png`

```- **Inference Time**: 2:44 (40 steps)

qwen-image-edit/- **Model Size**: 12.7GB quantized

├── api/                          # REST API server- **VRAM Usage**: ~23GB

│   ├── main.py                   # FastAPI application

│   ├── job_queue.py              # Queue management## 🛠️ System Requirements

│   ├── pipeline_manager.py       # Model loading

│   └── README.md                 # API documentation### Hardware

├── qwen_gradio_ui.py             # Web UI- **GPU**: NVIDIA GeForce RTX 4090 (24GB VRAM) or similar

├── test-api-remote.ps1           # Windows test script- **VRAM**: 24GB minimum

├── test-api-remote.sh            # macOS/Linux test script- **Disk Space**: ~50GB for models and dependencies

├── launch.ps1                    # Launch menu- **RAM**: 32GB recommended

└── README.md                     # This file- **Compute Capability**: 8.9 (sm_89)

```

### Software

## 🧪 Testing- **OS**: Windows 10/11

- **Python**: 3.10.6

Test scripts validate all API functionality (14 tests):- **CUDA**: 13.0 (or 12.1+)

- **Driver**: 581.29 or newer

**Windows:**- **Visual Studio Build Tools 2022**: With C++ components

```powershell

.\test-api-remote.ps1 "your-api-key"## 📦 Installation

```

### Step 1: Create Virtual Environment

**macOS/Linux:**

```bash**⚠️ CRITICAL: You MUST use a virtual environment!**

./test-api-remote.sh "your-api-key"

``````powershell

# Navigate to project directory

See [`TEST_SCRIPTS_README.md`](TEST_SCRIPTS_README.md) for details.cd C:\Projects\qwen-image-edit



## ⏱️ Performance# Create virtual environment

python -m venv .venv

| Model | Steps | Time | Quality |

|-------|-------|------|---------|# Activate it (DO THIS EVERY TIME)

| 4-step | 4 | ~10s | Good |.\.venv\Scripts\Activate.ps1

| 8-step | 8 | ~40s | Better |

| 40-step | 40 | ~3min | Best |# Verify activation - you should see (.venv) in your prompt

# Your prompt should look like: (.venv) PS C:\Projects\qwen-image-edit>

**Model Switching:** Takes 2-3 minutes due to GPU memory cleanup and model loading.```



## 📖 Documentation### Step 2: Install PyTorch with CUDA



- **API Documentation**: [`api/README.md`](api/README.md)```powershell

- **Installation Guide**: [`INSTALL_NUNCHAKU.md`](INSTALL_NUNCHAKU.md)# MAKE SURE (.venv) is showing in your prompt!

- **Test Scripts**: [`TEST_SCRIPTS_README.md`](TEST_SCRIPTS_README.md)pip install torch==2.5.1+cu121 torchvision==0.20.1+cu121 torchaudio==2.5.1+cu121 --index-url https://download.pytorch.org/whl/cu121

- **Flutter Integration**: [`FLUTTERFLOW_GUIDE.md`](FLUTTERFLOW_GUIDE.md)```

- **Changelog**: [`CHANGELOG.md`](CHANGELOG.md)

### Step 3: Install Diffusers from GitHub

## 🔒 API Authentication

**⚠️ Must be from GitHub for QwenImageEditPlusPipeline support**

The API uses API key authentication. Keys are auto-generated on first run.

```powershell

View your key:# MAKE SURE (.venv) is showing in your prompt!

```powershellpip install git+https://github.com/huggingface/diffusers.git

cd api```

.\show-api-key.ps1

```### Step 4: Install Other Dependencies



See [`api/README.md`](api/README.md) for authentication details.```powershell

# MAKE SURE (.venv) is showing in your prompt!

## 🎯 Example Usagepip install -r requirements.txt

```

### Gradio UI

1. Run `.\launch.ps1` → Select option 2### Step 5: Install nunchaku from Source

2. Upload image

3. Enter instruction: "Add Superman cape and suit"**⚠️ DO NOT use `pip install nunchaku` - that's a different package!**

4. Click Generate

See [INSTALL_NUNCHAKU.md](INSTALL_NUNCHAKU.md) for complete instructions.

### REST API

```python**Quick version:**

import requests```powershell

# MAKE SURE (.venv) is showing in your prompt!

headers = {"X-API-Key": "your-key"}

files = {"image": open("photo.jpg", "rb")}# Install Visual Studio Build Tools 2022 first (if not already installed)

data = {# Download from: https://visualstudio.microsoft.com/downloads/

    "instruction": "Transform into Superman",

    "model": "4-step"# Clone and build nunchaku

}cd $env:TEMP

git clone https://github.com/nunchaku-tech/nunchaku.git

response = requests.post(cd nunchaku

    "http://localhost:8000/api/v1/edit",git submodule update --init --recursive

    headers=headers,$env:TORCH_CUDA_ARCH_LIST="8.9"

    files=files,$env:DISTUTILS_USE_SDK="1"

    data=datapip install -e . --no-build-isolation

)

# Return to project

with open("output.png", "wb") as f:cd C:\Projects\qwen-image-edit

    f.write(response.content)```

```

**Verify nunchaku installation:**

## 🤝 Contributing```powershell

# Should show: nunchaku==1.0.1+torch2.5 (NOT 0.15.4!)

Contributions welcome! Please ensure:pip show nunchaku

- Code follows existing style```

- All tests pass

- Documentation is updated### Step 6: Run Prerequisites Check



## 📝 License```powershell

# MAKE SURE (.venv) is showing in your prompt!

See project license file..\check.ps1

```

## 🙏 Acknowledgments

## 🚀 Quick Start

- **Qwen Team**: For the Qwen Image Edit 2509 model

- **Nunchaku Team**: For INT4 quantization support**⚠️ ALWAYS activate venv first!**

- **HuggingFace**: For model hosting and diffusers library

```powershell
# Navigate to project
cd C:\Projects\qwen-image-edit

# Activate virtual environment (DO THIS EVERY TIME!)
.\.venv\Scripts\Activate.ps1

# Verify you see (.venv) in your prompt
# Prompt should show: (.venv) PS C:\Projects\qwen-image-edit>
```

### 🌟 Recommended: Gradio Web UI

**Easy-to-use web interface with all features!**

```powershell
# Start the web UI
python qwen_gradio_ui.py
```

Then open your browser to **http://127.0.0.1:7860**

**Features:**
- 🎨 Interactive web interface - no code editing needed
- 🔄 Switch between 3 models (4-step, 8-step, 40-step) on-the-fly
- 🎲 Random seeds for variety, or note seed for reproducibility
- 📝 Instruction-based editing with system prompts
- 🎭 Automatic face preservation
- 💾 Clean filenames: `qwen04_0001.png`, `qwen08_0042.png`, `qwen40_0001.png`

### 🖼️ Supported Image Formats

All interfaces (Gradio UI, REST API, CLI scripts) support:
- **PNG** (`.png`) - Recommended for images with transparency
- **JPEG** (`.jpg`, `.jpeg`) - Standard photo format

**API Limitations** (Gradio UI and CLI have no file size limits):
- Maximum file size: **10 MB**
- Maximum dimensions: **2048 x 2048 pixels**

### Command-Line Options

```powershell
# Multi-image composition (Sydney Harbour example)
python qwen_image_edit_nunchaku.py        # Standard 40-step (~2:45)
python qwen_image_edit_lightning.py       # Lightning 8-step (~21s)
python qwen_image_edit_lightning_4step.py # Lightning 4-step (~10s)

# Single-image instruction editing
python qwen_instruction_edit.py           # Edit script for custom instructions
```

**Generation Time**: 
- 40-step: ~2:45 (best quality)
- 8-step: ~21s ⚡ (7.7x faster, very good quality)
- 4-step: ~10s ⚡⚡ (16x faster, good quality)

**Output Files:**
- Gradio UI: `qwen04_0001.png`, `qwen08_0001.png`, `qwen40_0001.png` (sequential)
- Command-line: Timestamped filenames in `generated-images/` folder

**Output**: All generated images are saved in the `generated-images/` folder with sequential naming:
- **Gradio UI**: `qwen04_0001.png`, `qwen08_0001.png`, `qwen40_0001.png` (sequential per model)
- **CLI Scripts**: `output_r128_YYYYMMDD_HHMMSS.png` (timestamp-based for batch processing)

## 📊 Performance

### Gradio UI (Single Image Editing)
- **Lightning 4-step**: ~10 seconds/image (ultra-fast)
- **Lightning 8-step**: ~20 seconds/image (fast)
- **Standard 40-step**: ~2:45 minutes/image (best quality)

### CLI Scripts (Multi-Image Composition)
- **First Run**: ~5 minutes (model download + generation)
- **Subsequent Runs**: ~2-3 minutes (generation only)
- **Inference Steps**: 40 for standard, 8 or 4 for lightning

### System Requirements
- **VRAM Usage**: ~23GB during inference
- **Model Download Size**: 12.7GB per quantized model

## 📁 Project Structure

```
qwen-image-edit/
├── .venv/                                    # Virtual environment (do not commit)
├── api/                                      # REST API server
│   ├── main.py                              # FastAPI application
│   ├── models.py                            # Data models
│   ├── pipeline_manager.py                 # Model & queue management
│   ├── requirements.txt                     # API dependencies
│   ├── README.md                            # API documentation
│   ├── .api_key                             # Current API key (auto-generated)
│   ├── .api_key_history                     # API key history
│   ├── manage-key.ps1                       # Key management script
│   ├── new-api-key.ps1                      # Generate new key
│   └── show-api-key.ps1                     # Show current key
├── generated-images/                         # Generated images output folder
│   ├── api/                                 # API-generated images
│   │   ├── qwen04_0001.png                 # 4-step outputs
│   │   └── qwen40_0001.png                 # 40-step outputs
│   ├── qwen04_0001.png                      # 4-step model outputs
│   ├── qwen08_0001.png                      # 8-step model outputs
│   └── qwen40_0001.png                      # 40-step model outputs
├── qwen_gradio_ui.py                        # ⭐ WEB UI (Recommended!)
├── qwen_instruction_edit.py                 # Instruction-based editing script
├── qwen_image_edit_nunchaku.py              # Standard 40-step (best quality)
├── qwen_image_edit_lightning.py             # Lightning 8-step (fast)
├── qwen_image_edit_lightning_4step.py       # Lightning 4-step (ultra-fast)
├── launch.ps1                                # Launcher for API/Gradio
├── test-api-remote.ps1                       # Comprehensive API test suite
├── system_prompt.txt.example                # System prompt examples
├── check.ps1                                 # Prerequisites checker
├── install-nunchaku-patched.ps1             # Installation helper
├── requirements.txt                          # Python dependencies
├── README.md                                 # This file
├── NAMING_CONVENTION.md                      # File naming guide
├── INSTRUCTION_EDITING.md                    # Instruction editing docs
├── TODO.txt                                  # TODO list and improvements
└── .gitignore                                # Git ignore rules
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

## 🎛️ Model-Specific Parameters

**⚠️ CRITICAL: Different models require different parameters!**

### Standard Models (40 steps)
```python
inputs = {
    "num_inference_steps": 40,
    "true_cfg_scale": 4.0,      # High guidance for standard models
    "guidance_scale": 1.0,
    "negative_prompt": " ",
}
```
- **Quality**: Best
- **Speed**: Slow (~2:45 for 40 steps)
- **Use case**: Final production quality

### Lightning Models (8 steps)
```python
inputs = {
    "num_inference_steps": 8,
    "true_cfg_scale": 1.0,       # ⚠️ DIFFERENT! Lightning uses 1.0
    "guidance_scale": 1.0,
    "negative_prompt": " ",
}
```
- **Quality**: Very Good
- **Speed**: Fast (~21 seconds for 8 steps)
- **Use case**: Quick iterations, testing prompts

### Lightning Models (4 steps)
```python
inputs = {
    "num_inference_steps": 4,
    "true_cfg_scale": 1.0,       # Same as 8-step
    "guidance_scale": 1.0,
    "negative_prompt": " ",
}
```
- **Quality**: Good
- **Speed**: Very Fast (~10 seconds for 4 steps)
- **Use case**: Rapid prototyping

### 🔍 How to Find Optimal Parameters

**ALWAYS check the HuggingFace model card before using a new model!**

1. **Visit the model repository:**
   - Standard: https://huggingface.co/Qwen/Qwen-Image-Edit-2509
   - Lightning: https://huggingface.co/lightx2v/Qwen-Image-Lightning
   - Quantized: https://huggingface.co/nunchaku-tech/nunchaku-qwen-image-edit-2509

2. **Look for example code:**
   - Check the "Model card" tab
   - Look for usage examples with `DiffusionPipeline` or similar
   - Note the values for:
     - `num_inference_steps`
     - `true_cfg_scale` ⚠️ **Most important!**
     - `guidance_scale`

3. **Common mistakes:**
   - ❌ Using `true_cfg_scale=4.0` with Lightning → Blocky, pixelated output
   - ❌ Using wrong number of steps → Poor quality or wasted time
   - ❌ Assuming all models use same parameters → Unpredictable results

### 📋 Quick Reference Table

| Model Type | Steps | true_cfg_scale | Time | Quality | Script |
|------------|-------|----------------|------|---------|--------|
| Standard r128 | 40 | 4.0 | ~2:45 | Best | `qwen_image_edit_nunchaku.py` |
| Lightning 8-step r128 | 8 | 1.0 | ~21s | Very Good | `qwen_image_edit_lightning.py` |
| Lightning 4-step r128 | 4 | 1.0 | ~10s | Good | `qwen_image_edit_lightning_4step.py` |
| Standard r32 | 40 | 4.0 | ~2:00 | Good | (modify rank in script) |
| Lightning 8-step r32 | 8 | 1.0 | ~18s | Good | (modify rank in script) |

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

### ❌ Issue: Output image is blocky, pixelated, or low quality

**Cause**: Using wrong parameters for the model type!

**This happens when:**
- Using `true_cfg_scale=4.0` with Lightning models (should be 1.0)
- Using wrong number of inference steps
- Not checking the HuggingFace model card for optimal parameters

**Solution**:
```powershell
# 1. Check which model you're using
Get-Content your_script.py | Select-String "lightning"

# 2. If using Lightning model, check true_cfg_scale
Get-Content your_script.py | Select-String "true_cfg_scale"

# Should show:
# Lightning models: true_cfg_scale: 1.0  ✅
# Standard models:  true_cfg_scale: 4.0  ✅

# 3. Fix your script if needed:
# Lightning (8-step): true_cfg_scale=1.0, num_inference_steps=8
# Lightning (4-step): true_cfg_scale=1.0, num_inference_steps=4
# Standard (40-step): true_cfg_scale=4.0, num_inference_steps=40

# 4. ALWAYS check HuggingFace model card for new models:
#    https://huggingface.co/<model_name>
#    Look for example code with optimal parameters
```

**Prevention**: Before using any new model variant:
1. Visit the HuggingFace model page
2. Check the README for usage examples
3. Copy the exact parameters shown in examples
4. See "Model-Specific Parameters" section above

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
