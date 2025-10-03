# API Performance Investigation

## Problem
API is taking 37+ seconds for 4-step generation, while Gradio UI takes sub-20 seconds.

## Changes Made
1. ✅ Added detailed timing logs to `pipeline_manager.py`
2. ✅ Added CPU offloading (CRITICAL - was missing!)
   - Uses `enable_model_cpu_offload()` for >18GB GPU
   - Uses `enable_sequential_cpu_offload()` for <=18GB GPU
   - Matches Gradio UI implementation

## Timing Breakdown
Check the server terminal logs for detailed breakdown:
- Model loading time
- Transformer loading time
- Pipeline loading time
- Offloading configuration time
- Inference time

## Next Steps to Investigate
1. **Check server logs** - Look at the detailed timing output in the server terminal
2. **Compare with Gradio** - Run same prompt in Gradio UI and compare times
3. **First vs subsequent calls** - Model should be cached after first call
4. **Network overhead** - HTTP request/response vs direct Python call

## Expected Timings (from Gradio UI)
- **4-step model**: ~10-20 seconds total
- **8-step model**: ~20-40 seconds total
- **40-step model**: ~2:45-3:00 minutes total

## Potential Issues
- ~~Missing CPU offloading~~ ✅ FIXED
- HTTP overhead (minimal, should be <1s)
- Image encoding/decoding overhead
- Multiple model loads (should be cached)
- Progress bar configuration
- Memory management differences

## How to Test
```powershell
# Terminal 1: Start server and watch logs
cd C:\Projects\qwen-image-edit\api
..\\.venv\Scripts\Activate.ps1
python main.py

# Terminal 2: Test request
python -c "import requests; import time; start = time.time(); r = requests.post('http://localhost:8000/api/v1/edit', files={'image': ('test.png', open('generated-images/qwen-04_r128_20251002_113005.png', 'rb'), 'image/png')}, data={'instruction': 'Add sunglasses', 'model': '4-step', 'return_image': 'false'}); print(f'Total: {time.time()-start:.2f}s'); print(r.json())"
```

Check Terminal 1 for detailed breakdown of where time is spent.
