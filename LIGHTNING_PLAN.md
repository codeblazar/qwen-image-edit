# Lightning 8-Step Model Implementation Plan

## 🎯 Objective
Implement Lightning 8-step model to achieve 5x speed improvement (from ~2:45 to ~33 seconds per generation)

## ⚠️ CRITICAL: Lessons Learned (DO NOT REPEAT!)

### 1. **ALWAYS Use Virtual Environment**
```powershell
# EVERY TIME before running ANY Python command:
cd C:\Projects\qwen-image-edit
.\.venv\Scripts\Activate.ps1

# Verify (.venv) appears in prompt:
# (.venv) PS C:\Projects\qwen-image-edit>
```

### 2. **ALWAYS Use Correct Model**
- ✅ CORRECT: `nunchaku-tech/nunchaku-qwen-image-edit-2509/svdq-int4_r128-lightningv2.0-8steps`
- ❌ WRONG: `Qwen/Qwen-Image-Edit-2509` (40GB full model, causes OOM)

### 3. **ALWAYS Use Correct nunchaku Package**
- ✅ CORRECT: `nunchaku==1.0.1+torch2.5` (AI quantization library)
- ❌ WRONG: `nunchaku==0.15.4` (stats package from PyPI)
- Verify: `pip show nunchaku` (check version!)

## 📋 Step-by-Step Implementation

### Step 1: Create Lightning Script

**File**: `qwen_image_edit_lightning.py`

**Changes from original**:
```python
# Line 14-15: Change rank description
rank = 128  # Lightning model for 5x speed

# Line 17-19: Update print messages
print(f"Loading Nunchaku Lightning model (rank {rank}, 8-step)...")
print(f"Quantization: svdq-int4_r{rank}-lightningv2.0-8steps (~12.7GB)")
print("This Lightning model is 5x faster than standard!")

# Line 21-23: Change model path
transformer = NunchakuQwenImageTransformer2DModel.from_pretrained(
    f"nunchaku-tech/nunchaku-qwen-image-edit-2509/svdq-{get_precision()}_r{rank}-lightningv2.0-8steps-qwen-image-edit-2509.safetensors"
)

# Line 63: Change inference steps
"num_inference_steps": 8,  # Lightning model uses 8 steps instead of 40

# Line 75: Change output filename prefix
output_path = f"generated-images/lightning_r{rank}_{timestamp}.png"
```

**Complete script**: Create exact copy with modifications above

### Step 2: Test Execution (CRITICAL - Follow Exactly!)

```powershell
# 1. Navigate to project
cd C:\Projects\qwen-image-edit

# 2. Activate venv (CRITICAL!)
.\.venv\Scripts\Activate.ps1

# 3. VERIFY venv is active - prompt should show:
# (.venv) PS C:\Projects\qwen-image-edit>

# 4. Double-check correct nunchaku
pip show nunchaku
# Should show: Version: 1.0.1+torch2.5
# If shows 0.15.4 - STOP! Wrong package!

# 5. Run lightning script
python qwen_image_edit_lightning.py
```

### Step 3: Monitor First Run

**Expected behavior**:
1. Model download: ~12.7GB (first run only, ~2 min)
2. Loading messages: "Loading Nunchaku Lightning model..."
3. Pipeline setup: Same as standard
4. Generation: 8 steps instead of 40
5. **Expected time**: ~33 seconds (vs 2:45 for standard)
6. Output: `generated-images/lightning_r128_YYYYMMDD_HHMMSS.png`

**If errors occur**:
- "ModuleNotFoundError: No module named 'nunchaku'" → venv not active!
- "CUDA out of memory" → wrong 40GB model (check model path)
- "Import error" → wrong nunchaku package (check version)

### Step 4: Verify Results

```powershell
# Check output was created
ls generated-images/lightning_*.png

# Compare file sizes (should be similar)
ls generated-images/*.png | Select-Object Name, Length

# Time comparison:
# Standard: ~2:45 (40 steps × 4.1s)
# Lightning: ~33s (8 steps × 4.1s)
# Speed gain: 5x faster!
```

### Step 5: Quality Assessment

**Compare outputs**:
1. Open standard output: `generated-images/output_r128_*.png`
2. Open lightning output: `generated-images/lightning_r128_*.png`
3. Visual comparison for:
   - Detail preservation
   - Color accuracy
   - Artifact presence
   - Overall quality

**If quality acceptable**: ✅ Proceed to documentation
**If quality poor**: Consider 4-step model may be too fast

### Step 6: Update Documentation

**Files to update**:

1. **README.md**:
   - Add lightning script to Quick Start
   - Document speed vs quality tradeoff
   - Update performance metrics

2. **TODO.txt**:
   - Mark lightning implementation as complete
   - Note speed improvements achieved

3. **Project structure**:
   - Add qwen_image_edit_lightning.py to file list

### Step 7: Git Commit

```powershell
# Still in venv is fine, but not required for git

# Stage new file
git add qwen_image_edit_lightning.py

# Stage updated docs
git add README.md TODO.txt

# Commit
git commit -m "Add Lightning 8-step model for 5x speed improvement

- New script: qwen_image_edit_lightning.py
- Uses svdq-int4_r128-lightningv2.0-8steps model
- Reduces generation time from ~2:45 to ~33 seconds
- Maintains rank 128 quality with fewer steps
- Same VRAM usage (~23GB)
- Same model size (~12.7GB)

Speed comparison:
- Standard (40 steps): ~2:45
- Lightning (8 steps): ~33s
- Speed gain: 5x faster

Both scripts now available for users to choose speed vs quality."

# Push to GitHub
git push
```

## 📊 Expected Outcomes

| Metric | Standard | Lightning | Improvement |
|--------|----------|-----------|-------------|
| Steps | 40 | 8 | 5x reduction |
| Time | ~2:45 | ~33s | 5x faster |
| VRAM | ~23GB | ~23GB | Same |
| Model Size | 12.7GB | 12.7GB | Same |
| Quality | Excellent | Very Good | Acceptable tradeoff |

## 🚨 Pre-Flight Checklist

Before starting implementation:

- [ ] Virtual environment exists at `.venv/`
- [ ] nunchaku 1.0.1+torch2.5 installed (not 0.15.4!)
- [ ] ~13GB free disk space for new model
- [ ] No other GPU processes running
- [ ] Terminal ready to activate venv

## 🎯 Success Criteria

- [ ] Lightning script created without errors
- [ ] Model downloads successfully
- [ ] Generation completes in ~33 seconds (5x faster)
- [ ] Output quality is acceptable
- [ ] No CUDA OOM errors
- [ ] Documentation updated
- [ ] Changes committed and pushed to GitHub

## 🔄 Optional: Ultra-Fast 4-Step Variant

**Only proceed if 8-step quality is acceptable!**

Same process but:
- Model: `svdq-int4_r128-lightningv2.0-4steps`
- Steps: 4
- Time: ~16 seconds
- Script: `qwen_image_edit_ultra_fast.py`

---

**Ready to implement? Follow steps 1-7 exactly as written above!**
