# 🚨 ACTION PLAN: Fix Nunchaku Installation Issues

**Date Created:** October 25, 2025  
**Problem:** `ModuleNotFoundError: No module named 'nunchaku'` when launching Gradio UI

---

## 📋 ROOT CAUSE ANALYSIS

The error occurs because:

1. **Nunchaku is NOT installed** - The critical dependency that provides INT4 quantization for the **Qwen MMDiT (Multimodal Diffusion Transformer)** model
2. **Launch script doesn't check for nunchaku** - `launch.ps1` assumes all dependencies are installed
3. **Installation requires compilation** - Cannot simply `pip install nunchaku` (that's a different package!)
4. **Must compile from source** - Requires Visual Studio Build Tools and CUDA environment setup

**IMPORTANT:** Qwen Image Edit uses **MMDiT architecture** (Multimodal Diffusion Transformer), NOT traditional U-Net Stable Diffusion. It's Alibaba's vision-language transformer for instruction-based image editing.

---

## ✅ STEP-BY-STEP FIX PROCEDURE

### **PHASE 1: Verify Current Environment** ⏱️ 2 minutes

1. **Check if virtual environment is activated**
   ```powershell
   # Your prompt should show (.venv) at the start
   # If not, run:
   .\.venv\Scripts\Activate.ps1
   ```

2. **Verify Python and dependencies**
   ```powershell
   python --version           # Should be 3.10.6
   python -c "import torch; print(torch.__version__)"  # Should be 2.5.1+cu121
   python -c "import torch; print(torch.cuda.is_available())"  # Should be True
   nvcc --version            # Should show CUDA 13.0 or 12.1+
   ```

3. **Check if nunchaku is installed (it's not, but confirm)**
   ```powershell
   python -c "from nunchaku import NunchakuQwenImageTransformer2DModel"
   # Expected: ModuleNotFoundError (confirms the issue)
   ```

---

### **PHASE 2: Install Visual Studio Build Tools** ⏱️ 15-20 minutes

**⚠️ CRITICAL:** Nunchaku requires C++ compilation, so you MUST have MSVC compiler.

1. **Download Visual Studio 2022 Build Tools**
   - URL: https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022
   - File: `vs_BuildTools.exe`

2. **Run installer and select:**
   - ✅ **Desktop development with C++** (main workload)
   - Under "Individual components", ensure:
     - ✅ MSVC v143 - VS 2022 C++ x64/x86 build tools
     - ✅ Windows 10 SDK (10.0.xxxxx) or Windows 11 SDK
     - ✅ C++ CMake tools for Windows

3. **Install and wait** (10-15 minutes download + install)

4. **Verify installation**
   ```powershell
   # Should show Microsoft C++ Compiler version
   & "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
   cl.exe
   ```

---

### **PHASE 3: Install Nunchaku from Source** ⏱️ 15-20 minutes

Try these approaches in order - start with the simplest first:

---

#### **OPTION A: Direct Install from GitHub (SIMPLEST - TRY FIRST)**

From `INSTALL_NUNCHAKU.md` - this is the quickest method if it works:

```powershell
# Activate venv
.\.venv\Scripts\Activate.ps1

# Set CUDA architecture for RTX 4090
$env:TORCH_CUDA_ARCH_LIST='8.9'

# Install directly from GitHub
pip install --no-build-isolation git+https://github.com/nunchaku-tech/nunchaku.git
```

**If successful:** Skip to Phase 4 (Testing)

**If this fails with:**
- "CUDA mismatch" → Go to Option B
- "spdlog.h not found" → Go to Option C
- "cl.exe not found" → Go back to Phase 2 (VS Build Tools)

---

#### **OPTION B: Developer Command Prompt Method**

If Option A fails with CUDA version mismatch, use VS Developer tools:

```powershell
# 1. Search Windows Start Menu for "Developer Command Prompt for VS 2022"
# 2. Open it, then run:

cd C:\Projects\qwen-image-edit
.\.venv\Scripts\Activate.ps1
$env:TORCH_CUDA_ARCH_LIST='8.9'
pip install --no-build-isolation git+https://github.com/nunchaku-tech/nunchaku.git
```

**Alternative:** Set up VS environment in regular PowerShell:
```powershell
& "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\Launch-VsDevShell.ps1" -Arch amd64 -HostArch amd64
cd C:\Projects\qwen-image-edit
.\.venv\Scripts\Activate.ps1
$env:TORCH_CUDA_ARCH_LIST='8.9'
pip install --no-build-isolation git+https://github.com/nunchaku-tech/nunchaku.git
```

---

#### **OPTION C: Automated Patched Installer (if spdlog errors occur)**

If you get **"spdlog/spdlog.h: No such file or directory"** errors, the git submodules aren't being initialized. Use the automated script:

```powershell
# Make sure you're in the project root
cd C:\Projects\qwen-image-edit

# Activate venv if not already
.\.venv\Scripts\Activate.ps1

# Run the patched installer
.\install-nunchaku-patched.ps1
```

**What this script does:**
1. Verifies you're in the virtual environment
2. Patches PyTorch to bypass CUDA version mismatch (13.0 vs 12.1)
3. Sets up Visual Studio Build Tools environment
4. Sets `TORCH_CUDA_ARCH_LIST=8.9` for RTX 4090
5. Clones nunchaku repository to temp folder
6. **Initializes git submodules (fixes spdlog missing headers)**
7. Compiles and installs nunchaku from source
8. Verifies installation

**Expected output:**
```
Step 1: Patching PyTorch to bypass CUDA version check...
[OK] PyTorch patched successfully
Step 2: Setting up Visual Studio environment...
[OK] Visual Studio environment configured
Step 3: Setting CUDA compilation variables...
[OK] TORCH_CUDA_ARCH_LIST = 8.9 (sm_89)
Step 4: Cloning nunchaku repository...
Step 5: Initializing git submodules...
[OK] Submodules initialized
Step 6: Installing nunchaku from source...
This will take 10-15 minutes. Please be patient...
[... compilation output ...]
✓ Nunchaku imported successfully!
[SUCCESS] Nunchaku is ready to use!
```

---

#### **OPTION D: Manual Installation (last resort)**

If all automated methods fail, do it manually:

1. **Activate venv**
   ```powershell
   .\.venv\Scripts\Activate.ps1
   ```

2. **Patch PyTorch CUDA check**
   ```powershell
   # Edit this file:
   # .venv\Lib\site-packages\torch\utils\cpp_extension.py
   
   # Find line ~415:
   # raise RuntimeError(CUDA_MISMATCH_MESSAGE.format(cuda_str_version, torch.version.cuda))
   
   # Change to:
   # # raise RuntimeError(CUDA_MISMATCH_MESSAGE.format(cuda_str_version, torch.version.cuda))
   # pass  # Allow CUDA version mismatch
   ```

3. **Set up VS Build Tools environment**
   ```powershell
   # Run in PowerShell:
   & "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
   ```

4. **Clone and install nunchaku**
   ```powershell
   cd $env:TEMP
   git clone https://github.com/nunchaku-tech/nunchaku.git
   cd nunchaku
   git submodule update --init --recursive  # CRITICAL!
   
   # Set environment variables
   $env:TORCH_CUDA_ARCH_LIST='8.9'
   $env:DISTUTILS_USE_SDK='1'
   
   # Install (10-15 minutes)
   pip install -e . --no-build-isolation
   ```

5. **Verify installation**
   ```powershell
   python -c "from nunchaku import NunchakuQwenImageTransformer2DModel; print('Success!')"
   ```

---

### **PHASE 4: Test the Installation** ⏱️ 5 minutes

1. **Test Gradio UI**
   ```powershell
   cd C:\Projects\qwen-image-edit
   .\.venv\Scripts\Activate.ps1
   .\launch.ps1
   # Choose option [2] Gradio UI
   ```

   **Expected:** 
   - Gradio should start without errors
   - Browser opens to http://localhost:7860
   - You see the image editing interface

2. **Test API Server**
   ```powershell
   .\launch.ps1
   # Choose option [1] API Server
   ```

   **Expected:**
   - API starts on http://localhost:8000
   - Swagger UI accessible at http://localhost:8000/docs

---

## 🚨 COMMON ISSUES AND SOLUTIONS

### Issue 1: "Visual Studio Build Tools not found"
**Solution:** Reinstall VS Build Tools, ensure "Desktop development with C++" is selected

### Issue 2: "CUDA version mismatch" during nunchaku install
**Solution:** 
- Try Option B (Developer Command Prompt method)
- Or patch PyTorch's `cpp_extension.py` (see Option D)
- Or reinstall PyTorch with CUDA 11.8: `pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118`

### Issue 3: "spdlog/spdlog.h: No such file or directory"
**Solution:** Use Option C (automated patched installer) which initializes git submodules, or manually run `git submodule update --init --recursive` before installing

### Issue 4: Compilation takes forever or hangs
**Solution:** 
- Check Task Manager - `cl.exe` should be running
- Compilation takes 10-15 minutes normally
- If stuck >30 minutes, kill and retry

### Issue 5: "Access denied" when running install script
**Solution:** Run PowerShell as Administrator

### Issue 6: Launch.ps1 still opens external PowerShell window
**Solution:** This is normal behavior - it launches in a new window so you can see logs

---

## 📊 EXPECTED TIMELINE

| Phase | Task | Time | Total |
|-------|------|------|-------|
| 1 | Environment verification | 2 min | 2 min |
| 2 | Install VS Build Tools | 15-20 min | 17-22 min |
| 3 | Install nunchaku (Option A: direct) | 10-15 min | 27-37 min |
| 4 | Test installation | 5 min | 32-42 min |

**Total estimated time: 30-45 minutes** (if using simplest method)

**Note:** If Option A fails and you need Option C (patched script), add 5-10 minutes for patching and submodule init.

---

## ✅ SUCCESS CRITERIA

You'll know everything is working when:

1. ✅ No `ModuleNotFoundError` when importing nunchaku
2. ✅ Gradio UI launches and shows model selection
3. ✅ API server starts without errors
4. ✅ Can generate images without crashes

---

## 🎯 POST-INSTALLATION: FIRST RUN

After successful installation, the **first run** will:

1. **Download the quantized model** (~12.7 GB)
   - Takes 10-30 minutes depending on internet speed
   - Model cached to: `~/.cache/huggingface/hub/`
   - Only downloaded once, then reused

2. **Load model into VRAM**
   - Takes ~2-3 minutes to load
   - Uses ~23GB VRAM (you have 24GB on RTX 4090)

3. **Generate first image**
   - 4-step model: ~10 seconds
   - 8-step model: ~40 seconds
   - 40-step model: ~2:45 minutes

---

## 📝 NOTES

- **What is Qwen Image Edit?** Alibaba's **MMDiT (Multimodal Diffusion Transformer)** architecture for instruction-based image editing. It's a vision-language transformer, NOT traditional U-Net Stable Diffusion.

- **Why use diffusers library?** HuggingFace's `diffusers` library now supports multiple architectures including MMDiT models like Qwen, not just Stable Diffusion U-Nets.

- **Why .venv vs venv?** The dot prefix (`.venv`) hides the folder on Unix-like systems and keeps it out of search results. Functionally identical to `venv`, just a naming convention for cleanliness.

- **Why can't we pip install nunchaku?** The PyPI package "nunchaku" (v0.15.4) is a completely different statistics library. The AI model quantization library must be installed from GitHub source.

- **Why patch PyTorch?** Your system has CUDA 13.0 but PyTorch was built for CUDA 12.1/12.8. The strict version check causes installation to fail even though they're compatible at runtime.

- **Why is launch.ps1 opening external window?** The script uses `Start-Process powershell` to launch in a separate window so you can see real-time logs from the server/UI.

---

## 🆘 IF ALL ELSE FAILS

If nunchaku installation continues to fail after all attempts:

**Alternative: Use ComfyUI with Nunchaku Node**

1. Install ComfyUI: https://github.com/comfyanonymous/ComfyUI
2. Install ComfyUI-nunchaku plugin: https://github.com/nunchaku-tech/ComfyUI-nunchaku
3. This provides pre-built binaries, no compilation needed

This is a last resort, as it requires learning ComfyUI's node-based workflow instead of using this project's clean UI/API.

---

## 📞 DEBUGGING CHECKLIST

Before asking for help, verify:

- [ ] Virtual environment is activated (`.venv` in prompt)
- [ ] Python version is 3.10.6
- [ ] PyTorch 2.5.1+cu121 installed
- [ ] CUDA is available (`torch.cuda.is_available()` returns True)
- [ ] Visual Studio Build Tools 2022 installed with C++ components
- [ ] `cl.exe` is in PATH (run `cl.exe` to verify)
- [ ] Git submodules initialized before installing nunchaku
- [ ] PyTorch `cpp_extension.py` patched (if using manual method)
- [ ] No firewall/antivirus blocking compilation

---

**Good luck! Follow these steps carefully and you should be up and running in under an hour.** 🚀
