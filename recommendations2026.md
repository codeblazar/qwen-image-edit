# Recommendations (Conservative) — Jan 2026

This note summarizes conservative, low-risk improvements for this repo and how to verify the API is still working end-to-end.

## What the project currently uses

- Base pipeline: `Qwen/Qwen-Image-Edit-2509` via `QwenImageEditPlusPipeline`
- Quantized weights (transformer): `nunchaku-tech/nunchaku-qwen-image-edit-2509` (INT4)
- Step variants are *configs* (4/8/40 steps + cfg), not different base model IDs

Key code references:
- API model loader: [api/pipeline_manager.py](api/pipeline_manager.py)
- Gradio model loader: [qwen_gradio_ui.py](qwen_gradio_ui.py)

## Conservative recommendations

### 1) Pin “floating” dependencies (biggest stability win)

**Problem:** Diffusers is installed from GitHub “latest” (not pinned). This keeps you current, but it’s the main source of “it worked last week but not today” drift.

**Conservative change:** Pin Diffusers to a specific commit SHA (or a tagged release once `QwenImageEditPlusPipeline` is available on PyPI at a stable version), and document that exact version.

Why: You get reproducible installs and stable behavior without changing the model.

### 2) Make model IDs configurable (defaults unchanged)

**Problem:** The base model ID and nunchaku repo are hard-coded in multiple places.

**Conservative change:** Allow overriding via environment variables (keep current hard-coded values as defaults), e.g.:

- `QWEN_BASE_MODEL_ID` (default: `Qwen/Qwen-Image-Edit-2509`)
- `QWEN_NUNCHAKU_REPO` (default: `nunchaku-tech/nunchaku-qwen-image-edit-2509`)
- `QWEN_QUANT_RANK` / filename selector (default: r128)

Why: Lets you trial newer monthly variants safely without breaking existing users.

### 3) Reduce doc/code drift

**Observation:** This workspace includes `qwen_gradio_ui.py` and the FastAPI server under `api/`, but the README references scripts like `qwen_image_edit_nunchaku.py` which are not present here.

**Conservative change:** Update docs to point to the actual entrypoints in this repo (Gradio + API), or restore the missing scripts if they are expected.

Why: Prevents operator error and makes verification simpler.

### 4) Add “reproducibility visibility” (logging only)

**Conservative change:** On startup, log/return:

- Resolved HF model ID and snapshot/commit hash (the actual cached revision)
- Selected safetensors filename for nunchaku transformer
- Diffusers version and (if installed from git) commit SHA

Why: If output quality changes later, you can tell *what changed*.

### 5) Clarify wording: “step presets” vs “models”

**Conservative change:** In docs, describe 4/8/40-step as presets/configs, not separate model checkpoints.

Why: Reduces user confusion and support load.

### 6) Evaluate newer Qwen monthly variants only via a staged process

As of Jan 2026, `Qwen-Image-Edit-2509` is unlikely to be the most recent monthly iteration. The conservative approach is:

1. Keep `2509` as the default.
2. Trial a newer base model ID in a separate environment.
3. Confirm a matching nunchaku quantized weight set exists (same family).
4. Validate on a small “golden set” of images and prompts.
5. Only then consider switching defaults.

## How to verify it still works (end-to-end)

There are multiple test clients in this repo:

- Python client example: [test_api.py](test_api.py) (targets the public URL and currently has a hard-coded API key)
- Comprehensive local test suite: [api/test_api_comprehensive.py](api/test_api_comprehensive.py)
- PowerShell remote tester mentioned in README: `test-api-remote.ps1`

### Option A (recommended): Local API + comprehensive test

1) Start the local API server

```powershell
cd C:\Projects\qwen-image-edit
.\.venv\Scripts\Activate.ps1
.\launch.ps1
# Choose option 2: API Server Only (Local Development)
```

2) Confirm health endpoint

```powershell
Invoke-WebRequest -Uri "http://localhost:8000/api/v1/health" | Select-Object -ExpandProperty Content
```

3) Run the comprehensive test suite

- Open `api/test_api_comprehensive.py` and set `API_BASE` to `http://localhost:8000/api/v1` (it currently points at a LAN IP).
- Then run:

```powershell
cd C:\Projects\qwen-image-edit\api
python .\test_api_comprehensive.py
```

What you should see: a sequence of PASS/FAIL results for health/auth/models/load-model/edit/queue behavior.

### Option B: Remote API test via PowerShell script

If you want to validate the deployed endpoint (Cloudflare URL), use the existing script referenced in the README:

```powershell
cd C:\Projects\qwen-image-edit
.\test-api-remote.ps1 "your-api-key"
```

(If you have debug output enabled in that script, you can run its debug mode as documented in the README.)

### Option C: Simple Python API call (remote)

The repo contains a Python client example at [test_api.py](test_api.py).

```powershell
cd C:\Projects\qwen-image-edit
.\.venv\Scripts\Activate.ps1
python .\test_api.py
```

Notes:
- This script targets `https://qwen.codeblazar.org/api/v1` and includes a hard-coded API key; treat it as an example client.
- It expects an input image named `test.png` in the same folder.

## Quick sanity checklist

- `GET /api/v1/health` returns 200
- `GET /api/v1/models` returns 3 presets (4/8/40)
- `POST /api/v1/load-model?model=4-step` succeeds
- `POST /api/v1/edit` returns an image (or a job completes if using the queue endpoints)
