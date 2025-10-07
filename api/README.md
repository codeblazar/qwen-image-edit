# Qwen Image Edit API

REST API with Swagger/OpenAPI interface for instruction-based image editing using Qwen models.

## 🎯 Overview

This API provides a REST interface to the Qwen Image Edit models, allowing you to:
- Upload images and edit them with natural language instructions
- Preserve facial features and identity automatically
- Choose between 3 models (4-step, 8-step, 40-step) for speed vs quality
- Get edited images back in the response or save them to disk

### 🖼️ Supported Image Formats

The API accepts the following image formats:
- **PNG** (`.png`) - Recommended for images with transparency
- **JPEG** (`.jpg`, `.jpeg`) - Standard photo format
  
**Limitations:**
- Maximum file size: **10 MB**
- Maximum dimensions: **2048 x 2048 pixels**
- Files larger than limits will be rejected with HTTP 400

## 📋 Prerequisites

**You must install the main Qwen project first!**

1. Follow the installation instructions in the main [README.md](../README.md)
2. Ensure the virtual environment is set up with all dependencies
3. Verify you can run the Gradio UI successfully

## 🚀 Quick Start

### 1. Install API Dependencies

From the **main project directory** (`qwen-image-edit`), activate the virtual environment and install API requirements:

```powershell
# Activate virtual environment
.\.venv\Scripts\Activate.ps1

# Install API dependencies
pip install -r api/requirements.txt
```

### 2. Start the API Server

```powershell
# From main project directory
cd api
python main.py
```

Or use uvicorn directly:

```powershell
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### 3. Access Swagger UI

Open your browser to:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **API Root**: http://localhost:8000/

## 📡 API Endpoints

### `GET /api/v1/health`
Health check endpoint

**Response:**
```json
{
  "status": "healthy",
  "current_model": "4-step",
  "model_loaded": true
}
```

### `GET /api/v1/models`
List all available models with specifications

**Response:**
```json
{
  "models": {
    "4-step": {
      "name": "Lightning 4-step (Ultra Fast)",
      "steps": 4,
      "cfg_scale": 1.0,
      "estimated_time": "~20 seconds",
      "description": "Ultra-fast generation with good quality"
    },
    "8-step": { ... },
    "40-step": { ... }
  },
  "note": "Switching models between generations will take several minutes for model loading"
}
```

### `POST /api/v1/edit`
Edit an image based on text instruction

**Request (multipart/form-data):**
- `image` (file, required): Input image (PNG, JPG, or JPEG)
- `instruction` (string, required): Editing instruction
- `model` (string, optional): "4-step", "8-step", or "40-step" (default: "4-step")
- `seed` (integer, optional): Random seed for reproducibility
- `system_prompt` (string, optional): System prompt for styling
- `return_image` (boolean, optional): Return image in response (default: true)

**Supported Image Formats:**
- PNG (`.png`) - Recommended for transparency
- JPEG (`.jpg`, `.jpeg`) - Standard photo format
- Maximum size: 10MB
- Maximum dimensions: 2048x2048 pixels

**Response:**
- If `return_image=true`: PNG image in response body with headers:
  - `X-Seed`: Seed used for generation
  - `X-Model`: Model used
  - `X-Saved-Path`: Where image was saved
- If `return_image=false`: JSON with filepath and metadata

**Example using curl:**
```powershell
curl -X POST "http://localhost:8000/api/v1/edit" `
  -H "X-API-Key: your-api-key-here" `
  -F "image=@my_photo.jpg" `
  -F "instruction=Transform this person into Superman with cape and suit" `
  -F "model=4-step" `
  --output edited_image.png
```

**Example using Python:**
```python
import requests

headers = {"X-API-Key": "your-api-key-here"}

with open("my_photo.jpg", "rb") as f:
    response = requests.post(
        "http://localhost:8000/api/v1/edit",
        files={"image": f},
        headers=headers,
        data={
            "instruction": "Make this person into Superman",
            "model": "4-step",
            "seed": 42
        }
    )

# Save edited image
with open("output.png", "wb") as out:
    out.write(response.content)

# Check headers for metadata
print(f"Seed: {response.headers.get('X-Seed')}")
print(f"Saved to: {response.headers.get('X-Saved-Path')}")
```

## ⏱️ Performance

### Generation Times (after model loaded)
- **4-step**: ~20 seconds
- **8-step**: ~40 seconds  
- **40-step**: ~3 minutes

### Model Switching
**⚠️ Important:** Switching between models takes **several minutes** due to:
1. Unloading previous model (~30s)
2. Loading new model (~2-3 minutes for download/cache if first time)
3. GPU memory cleanup

**Recommendation:** Stick with one model for batch processing, or use the 4-step model for API use.

## 📁 Output Files

All API-generated images are saved to:
```
generated-images/api/
├── qwen04_0001.png    # 4-step model outputs
├── qwen04_0002.png
├── qwen08_0001.png    # 8-step model outputs
└── qwen40_0001.png    # 40-step model outputs
```

Files are numbered sequentially per model type.

## 🔒 Authentication

The API uses **API Key authentication** to protect endpoints.

### Setting Up Your API Key

**The API automatically manages keys for you!**

The first time you run `launch.ps1` and select option 1 (API Server), it will:
1. Check if an API key exists in `.api_key`
2. If not, automatically generate a secure one
3. Display the key for you to use
4. Store it with a timestamp in `.api_key_history`

**Manual Key Management:**

```powershell
# Generate a new API key
.\api\new-api-key.ps1

# Show current API key
.\api\show-api-key.ps1

# Rotate to a new key (archives old one)
.\api\manage-key.ps1 -Rotate
```

**Key Storage:**
- Current key: `api/.api_key` (ASCII encoded to avoid UTF-8 BOM issues)
- Key history: `api/.api_key_history` (timestamped archive of all keys)

### Key Security

✅ **Secure by default:** Each installation generates a unique 43-character key
✅ **Automatic management:** No manual configuration needed
✅ **History tracking:** All keys are archived with timestamps
✅ **Easy rotation:** Use `manage-key.ps1 -Rotate` to change keys

⚠️ **IMPORTANT:** Keep your `.api_key` file secure! Don't commit it to git (already in `.gitignore`).

**3. Use the API key in requests:**

Include the header `X-API-Key: your-key-here` in all requests to protected endpoints.

### Protected Endpoints
- ✅ `POST /api/v1/submit` - Submit image editing job (queued processing)
- ✅ `GET /api/v1/status/{job_id}` - Get job status
- ✅ `GET /api/v1/result/{job_id}` - Download result image
- ✅ `POST /api/v1/load-model` - Load a specific model
- ✅ `GET /api/v1/models` - List available models

### Public Endpoints (No API Key Required)
- 🌐 `GET /` - API info
- 🌐 `GET /api/v1/health` - Health check
- 🌐 `GET /api/v1/queue` - Queue status

### Testing with API Key

**Swagger UI:**
1. Go to http://localhost:8000/docs
2. Click the "Authorize" 🔒 button at the top
3. Enter your API key in the `X-API-Key` field
4. Click "Authorize"
5. Now you can test protected endpoints

**curl:**
```powershell
curl -X POST "http://localhost:8000/api/v1/edit" `
  -H "X-API-Key: your-key-here" `
  -F "image=@photo.jpg" `
  -F "instruction=Add sunglasses"
```

**Python:**
```python
import requests

headers = {"X-API-Key": "your-key-here"}
response = requests.post(url, files=files, data=data, headers=headers)
```

### Default Key (INSECURE - Change Before Production!)

If no environment variable is set, the API uses: `changeme-insecure-default-key`

⚠️ **IMPORTANT:** Always change this before exposing via Cloudflare Tunnel or deploying to production!

## 🌐 Cloudflare Tunnel Setup

The API works perfectly with Cloudflare Tunnels:

1. **Set a secure API key first!** (See Authentication section above)

2. Install `cloudflared`
```powershell
winget install --id Cloudflare.cloudflared
```

3. Run tunnel:
```powershell
cloudflared tunnel --url http://localhost:8000
```

4. Access via public URL provided by Cloudflare (e.g., `https://random-name.trycloudflare.com`)

5. Include API key in all requests:
```powershell
curl -X POST "https://your-tunnel.trycloudflare.com/api/v1/edit" `
  -H "X-API-Key: your-secure-key-here" `
  -F "image=@photo.jpg" `
  -F "instruction=Add sunglasses"
```

⚠️ **Security:** Your API is protected by the API key. Without it, requests will receive 401 Unauthorized.

## 🐛 Troubleshooting

### Port Already in Use
```powershell
# Find process using port 8000
netstat -ano | findstr :8000

# Kill process (replace PID)
taskkill /PID <PID> /F

# Or use a different port
uvicorn main:app --port 8001
```

### CUDA Out of Memory
- Only one model can be loaded at a time
- The API automatically unloads models when switching
- If issues persist, restart the API server

### Model Download Failed
- Check internet connection
- Ensure you have ~13GB free disk space per model
- Models cache in HuggingFace cache directory

### Image Upload Failed
- Ensure image is JPG or PNG
- Check file size (recommended < 10MB)
- Verify image is not corrupted

## 📚 API Documentation

Once the server is running, interactive documentation is available at:

- **Swagger UI** (interactive testing): http://localhost:8000/docs
- **ReDoc** (clean reference): http://localhost:8000/redoc

## 🔄 Differences from Gradio UI

| Feature | Gradio UI | API |
|---------|-----------|-----|
| Interface | Web browser GUI | REST API |
| Access | http://localhost:7860 | http://localhost:8000 |
| Authentication | None | None (add if needed) |
| Model Selection | Radio buttons | `model` parameter |
| Output Location | `generated-images/` | `generated-images/api/` |
| Response | Display in browser | PNG in HTTP response |
| Best For | Interactive testing | Automation, integrations |

## 🧪 Testing

### Comprehensive Test Suite

The project includes a robust PowerShell test script that validates all API functionality:

```powershell
# Run against local server
.\test-api-remote.ps1 -ApiKey "your-api-key" -BaseUrl "http://localhost:8000/api/v1"

# Run against production (Cloudflare Tunnel)
.\test-api-remote.ps1 -ApiKey "your-api-key" -BaseUrl "https://qwen.codeblazar.org/api/v1"
```

**Test Coverage (14 tests):**
1. ✅ Health check endpoint
2. ✅ Authentication rejection (invalid key)
3. ✅ Model listing
4. ✅ Queue status reporting
5. ✅ Model loading
6. ✅ Job submission
7. ✅ Job status tracking
8. ✅ Job completion and results
9. ✅ Multiple concurrent jobs
10. ✅ **Queue overflow protection** (fills queue to capacity)
11. ✅ **Queue status under load** (metrics accuracy)
12. ✅ **Queue position tracking** (job state transitions)
13. ✅ Oversized image rejection
14. ✅ Invalid job ID handling

**Queue Testing:**
The test suite includes comprehensive queue validation:
- Fills queue to maximum capacity (10 jobs)
- Verifies overflow handling and 429 responses
- Checks queue metrics accuracy under load
- Tracks job progression (queued → processing → completed)
- Validates queue drainage and cleanup

**Test Requirements:**
- PowerShell 5.1 or later
- API server running (local or remote)
- Valid API key
- Test image will be auto-generated

**Expected Results:**
```
================================================================
                       Test Summary
================================================================
Total Tests:  14
Passed:       14
Failed:       0
Pass Rate:    100%

ALL TESTS PASSED!
```

## 📝 Example Use Cases

1. **Batch Processing**: Process multiple images programmatically
2. **Integration**: Integrate with other apps/services
3. **Automation**: Automated editing pipelines
4. **Mobile Apps**: Backend for mobile image editing apps
5. **Web Services**: Embed in web applications
6. **CI/CD**: Automated testing with image generation

## 🛠️ Development

### Running in Development Mode
```powershell
uvicorn main:app --reload --port 8000
```

The `--reload` flag auto-restarts the server when code changes.

### Testing with Swagger UI
1. Go to http://localhost:8000/docs
2. Click on an endpoint (e.g., `POST /api/v1/edit`)
3. Click "Try it out"
4. Upload an image and fill in parameters
5. Click "Execute"
6. Download the result from the response

## 📄 License

Same as main project. See [../README.md](../README.md).

## 🆘 Support

For issues specific to the API, check:
1. This README
2. Swagger UI documentation at `/docs`
3. Main project README for model setup

For Qwen model issues, refer to the main project documentation.
