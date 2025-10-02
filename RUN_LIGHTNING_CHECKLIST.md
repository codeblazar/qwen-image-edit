# Pre-Flight Verification Checklist
# Run these commands BEFORE executing the lightning script

## ✅ Step-by-Step Verification

### 1. Navigate to Project
```powershell
cd C:\Projects\qwen-image-edit
```

### 2. Activate Virtual Environment (CRITICAL!)
```powershell
.\.venv\Scripts\Activate.ps1
```

### 3. Verify (.venv) Appears in Prompt
Your prompt should now show:
```
(.venv) PS C:\Projects\qwen-image-edit>
```

**If (.venv) is NOT showing → STOP! Virtual environment is not active!**

### 4. Verify Correct nunchaku Package
```powershell
pip show nunchaku
```

**Expected output:**
```
Name: nunchaku
Version: 1.0.1+torch2.5
Location: C:\Users\...\AppData\Local\Temp\nunchaku
```

**If Version shows 0.15.4 → STOP! Wrong nunchaku package (stats library)!**

### 5. Check Disk Space
```powershell
Get-PSDrive C | Select-Object Used,Free
```

**Need:** At least 13GB free (for new lightning model download)

### 6. Verify GPU is Available
```powershell
python -c "import torch; print('CUDA Available:', torch.cuda.is_available()); print('GPU:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'None')"
```

**Expected output:**
```
CUDA Available: True
GPU: NVIDIA GeForce RTX 4090
```

### 7. Check No Other GPU Processes
```powershell
nvidia-smi
```

**Look for:** Low GPU memory usage (should be mostly free)

---

## ✅ All Checks Passed?

If ALL verifications above passed, proceed with:

```powershell
python qwen_image_edit_lightning.py
```

---

## ⚠️ What to Expect

### First Run (Model Download):
- Download: ~12.7GB Lightning model
- Time: ~2-3 minutes
- One-time only

### Generation:
- Pipeline loading: ~10 seconds
- Image generation: ~33 seconds (8 steps × ~4s/step)
- Total: ~45 seconds after model is cached

### Output:
```
generated-images/lightning_r128_YYYYMMDD_HHMMSS.png
```

---

## 🚨 If Errors Occur

### "ModuleNotFoundError: No module named 'nunchaku'"
**Cause:** Virtual environment not activated
**Fix:** Run `.\.venv\Scripts\Activate.ps1` and verify (.venv) in prompt

### "CUDA out of memory"
**Cause:** Wrong model (40GB full model) or other GPU processes
**Fix:** Check model path in script, close other GPU apps, run `nvidia-smi`

### "Import error" or wrong nunchaku functions
**Cause:** Wrong nunchaku package (0.15.4 stats library)
**Fix:** `pip uninstall nunchaku -y` then reinstall from source

---

**Ready to proceed? Run the checklist above, then execute the script!**
