# Qwen Image Edit 2509

AI-powered multi-image editing using Qwen's Image Edit model with quantized transformers for 24GB VRAM GPUs.

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

## ✅ Installation Status

### Completed:
1. ✅ Virtual environment created (`.venv`)
2. ✅ PyTorch 2.5.1+cu121 installed with CUDA support
3. ✅ diffusers 0.36.0.dev0 (from GitHub) installed
4. ✅ All dependencies installed (transformers, accelerate, pillow, requests, peft, einops, protobuf, sentencepiece)
5. ✅ Visual Studio Build Tools 2022 installed with C++ components
6. ✅ PyTorch patched to bypass CUDA version check (13.0 vs 12.1)
7. ✅ nunchaku compiled and installed from source
8. ✅ Successfully generated first image!

## 🚀 Quick Start

```powershell
# Activate virtual environment
.\.venv\Scripts\Activate.ps1

# Run image generation
python qwen_image_edit_nunchaku.py
```

The script will:
1. Download the quantized model (~12.7GB) on first run
2. Download sample images from Qwen examples
3. Generate an edited image combining both inputs
4. Save output to `output_image_edit_plus_r128.png`

**Generation Time**: ~2-3 minutes after model is downloaded

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
├── qwen_image_edit_nunchaku.py    # Main script
├── check.ps1                       # Prerequisites checker
├── install-nunchaku-patched.ps1   # Installation helper
├── README.md                       # This file
├── TODO.txt                        # TODO list and improvements
├── .gitignore                      # Git ignore rules
└── output_image_edit_plus_*.png   # Generated images
```

## 🔧 Model Options

### ✅ Quantized Models (Recommended - Fits on RTX 4090)

**Standard Models (40 steps):**
- `svdq-int4_r32` (11.5 GB)
- `svdq-int4_r128` (12.7 GB) ⭐ **Best Quality** (currently used)

**Lightning Models (8 steps - Faster):**
- `svdq-int4_r32-lightningv2.0-8steps`
- `svdq-int4_r128-lightningv2.0-8steps` ⭐ **Best Balance**

**Lightning Models (4 steps - Fastest):**
- `svdq-int4_r32-lightningv2.0-4steps`
- `svdq-int4_r128-lightningv2.0-4steps`

All models from: `nunchaku-tech/nunchaku-qwen-image-edit-2509`

### ❌ Full Model (Not Compatible)
- `Qwen/Qwen-Image-Edit-2509` (~40GB)
- **Does NOT fit on RTX 4090 24GB VRAM**
- Causes OOM errors

## 🛠️ Installation (Detailed)

See [INSTALL_NUNCHAKU.md](INSTALL_NUNCHAKU.md) for complete installation instructions including:
- Visual Studio Build Tools setup
- PyTorch CUDA patch
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

## 🐛 Troubleshooting

### Issue: "ModuleNotFoundError: No module named 'nunchaku'"
**Solution**: Make sure you're in the virtual environment and nunchaku is installed.

### Issue: "CUDA out of memory"
**Solution**: The model requires 24GB VRAM. Close other applications using GPU.

### Issue: Compilation fails during nunchaku installation
**Solution**: Ensure Visual Studio Build Tools 2022 with C++ components is installed. See [INSTALL_NUNCHAKU.md](INSTALL_NUNCHAKU.md).

### Issue: Wrong nunchaku package installed (stats package)
**Solution**: Uninstall the stats package and install from GitHub:
```powershell
pip uninstall nunchaku -y
# Follow installation instructions in INSTALL_NUNCHAKU.md
```

---

**Made with ❤️ for AI image editing on consumer GPUs**
