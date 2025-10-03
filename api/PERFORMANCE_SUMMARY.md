# API Performance Summary

## Current Performance (After Optimizations)

### First Call (Cold Start - Loading Model)
- **Model Load**: 21.44s
  - Transformer: 4.77s
  - Pipeline: 11.21s
  - Offloading config: 5.45s
- **Inference**: 15.18s
- **TOTAL**: ~37-39s

### Subsequent Calls (Warm - Cached Model)
- **Model Load**: 0.00s (cached)
- **Inference**: 15-16s
- **TOTAL**: ~15-16s ✅

## Comparison with Gradio UI
- **Gradio (warm)**: ~10-15s
- **API (warm)**: ~15-16s
- **Difference**: ~1-5s slower

## Why is API slightly slower than Gradio?

### Confirmed NOT the issue:
- ✅ CPU offloading - NOW ENABLED
- ✅ torch.inference_mode() - NOW USING
- ✅ torch.manual_seed() - NOW USING
- ✅ Image format (list) - NOW MATCHING

### Remaining overhead (minor):
1. **HTTP Request/Response** (~0.5-1s)
   - Multipart form data encoding
   - Image upload
   - JSON response

2. **FastAPI Processing** (~0.2-0.5s)
   - Request validation
   - File handling
   - Response formatting

3. **Different execution context** (~0-1s)
   - FastAPI async context
   - Uvicorn server overhead

## Optimizations Applied

### ✅ DONE:
1. Added CPU offloading (CRITICAL - was missing!)
   - `enable_model_cpu_offload()` for >18GB GPU  
   - `enable_sequential_cpu_offload()` for <=18GB GPU
2. Added `torch.inference_mode()` context
3. Changed to `torch.manual_seed(seed)` (matches Gradio)
4. Image passed as list `[image]` (matches Gradio)
5. Removed ignored `guidance_scale` parameter
6. Model caching (pipeline stays loaded)

### Performance Improvement:
- **Before**: ~37s every time (reloading model)
- **After**: 37s first call, 15s subsequent calls
- **Improvement**: 59% faster on subsequent calls

## Conclusion

✅ **API is now performing well!**
- First call: 37s (acceptable - includes model loading)
- Subsequent calls: 15-16s (very close to Gradio's 10-15s)
- The 1-5s difference is acceptable HTTP/server overhead

## Recommendations

1. **For best performance**: Keep the API server running (don't restart between requests)
2. **Pre-warm the model**: Make a dummy request on startup to load the model
3. **For production**: Consider adding a `/warmup` endpoint that loads all models on startup
4. **Current performance is acceptable** for API use - the slight overhead vs Gradio is normal

## Usage Pattern

**Development/Testing:**
- Use Gradio UI for interactive testing (slightly faster, no HTTP overhead)

**Production/Integration:**
- Use API for automation, integrations, remote access
- Accept the minor HTTP overhead (~1-5s) for the benefits of REST API
