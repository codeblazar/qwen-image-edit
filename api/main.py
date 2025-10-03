"""
FastAPI REST API for Qwen Image Edit
Provides Swagger/OpenAPI interface for instruction-based image editing
"""
from fastapi import FastAPI, File, UploadFile, Form, HTTPException, Header, Depends
from fastapi.responses import Response, JSONResponse
from PIL import Image
import io
import os
from datetime import datetime
from pathlib import Path
from typing import Optional
import glob

from models import ModelInfo, HealthResponse
from pipeline_manager import PipelineManager


# Initialize FastAPI app
app = FastAPI(
    title="Qwen Image Edit API",
    description="REST API for instruction-based image editing using Qwen models",
    version="1.0.0",
    docs_url="/docs",  # Swagger UI at /docs
    redoc_url="/redoc"  # ReDoc at /redoc
)

# Initialize pipeline manager
pipeline_manager = PipelineManager()

# Output directory for API-generated images
OUTPUT_DIR = Path("../generated-images/api")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# API Key Configuration
# IMPORTANT: Change this to a secure random key in production!
# Generate a secure key with: python -c "import secrets; print(secrets.token_urlsafe(32))"
API_KEY = os.getenv("QWEN_API_KEY", "changeme-insecure-default-key")

# API Key Authentication
async def verify_api_key(x_api_key: str = Header(..., description="API Key for authentication")):
    """
    Verify the API key from the X-API-Key header.
    
    To use: Include header 'X-API-Key: your-key-here' in requests
    """
    if x_api_key != API_KEY:
        raise HTTPException(
            status_code=401,
            detail="Invalid or missing API key"
        )
    return x_api_key


def get_next_image_number(model_prefix: str) -> int:
    """Get next sequential number for the given model prefix"""
    pattern = str(OUTPUT_DIR / f"{model_prefix}-api_*.png")
    existing_files = glob.glob(pattern)
    
    if not existing_files:
        return 1
    
    numbers = []
    for filepath in existing_files:
        filename = Path(filepath).stem
        try:
            # Split on '-api_' to get the number
            num = int(filename.split('-api_')[1])
            numbers.append(num)
        except (IndexError, ValueError):
            continue
    
    return max(numbers) + 1 if numbers else 1


def save_image(image: Image.Image, model_key: str) -> str:
    """Save image with sequential naming and return filepath"""
    # Map model key to prefix
    prefix_map = {
        "4-step": "qwen04",
        "8-step": "qwen08",
        "40-step": "qwen40"
    }
    prefix = prefix_map.get(model_key, "qwen")
    
    # Get next number
    next_num = get_next_image_number(prefix)
    
    # Create filename with format: qwen04-api_001.png
    filename = f"{prefix}-api_{next_num:03d}.png"
    filepath = OUTPUT_DIR / filename
    
    # Save image
    image.save(filepath, format="PNG")
    
    return str(filepath)


@app.get("/", tags=["General"])
async def root():
    """Root endpoint with API information"""
    return {
        "message": "Qwen Image Edit API",
        "version": "1.0.0",
        "docs": "/docs",
        "redoc": "/redoc",
        "endpoints": {
            "edit": "POST /api/v1/edit",
            "models": "GET /api/v1/models",
            "health": "GET /api/v1/health"
        }
    }


@app.get("/api/v1/health", response_model=HealthResponse, tags=["General"])
async def health_check():
    """Health check endpoint"""
    return HealthResponse(
        status="healthy",
        current_model=pipeline_manager.current_model,
        model_loaded=pipeline_manager.pipeline is not None
    )


@app.post("/api/v1/warmup", tags=["General"], dependencies=[Depends(verify_api_key)])
async def warmup(model: str = "4-step"):
    """
    Warmup endpoint - Pre-loads a model to avoid cold start delays
    
    Call this endpoint after server startup to pre-load the model into memory.
    Subsequent /edit requests will be much faster.
    
    Args:
        model: Model to warm up (default: "4-step")
        
    Returns:
        Status and timing information
    """
    import time
    start = time.time()
    
    try:
        # Validate model
        if model not in ["4-step", "8-step", "40-step"]:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid model: {model}. Must be one of: 4-step, 8-step, 40-step"
            )
        
        # Load the model
        pipeline_manager.load_model(model)
        
        elapsed = time.time() - start
        
        return {
            "status": "success",
            "message": f"Model {model} warmed up and ready",
            "model": model,
            "load_time_seconds": round(elapsed, 2),
            "cached": True
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/models", tags=["Models"])
async def list_models():
    """
    List all available models with specifications
    
    Returns information about each model including:
    - Name and description
    - Inference steps
    - CFG scale
    - Estimated generation time
    """
    models = pipeline_manager.list_models()
    return {
        "models": {
            key: ModelInfo(
                name=config["name"],
                suffix=config["suffix"],
                steps=config["steps"],
                cfg_scale=config["cfg_scale"],
                estimated_time=config["estimated_time"],
                description=config["description"]
            )
            for key, config in models.items()
        },
        "note": "Switching models between generations will take several minutes for model loading"
    }


@app.post("/api/v1/edit", tags=["Image Editing"], dependencies=[Depends(verify_api_key)])
async def edit_image(
    image: UploadFile = File(..., description="Input image (JPG, PNG)"),
    instruction: str = Form(..., description="Editing instruction (e.g., 'Make this person into Superman')"),
    model: str = Form(
        default="4-step",
        description="Model to use: 4-step (~20s), 8-step (~40s), or 40-step (~3min)"
    ),
    seed: Optional[int] = Form(
        default=None,
        description="Random seed for reproducibility. If not provided, uses random seed."
    ),
    system_prompt: Optional[str] = Form(
        default=None,
        description="Optional system prompt for styling (e.g., 'cinematic lighting, photorealistic')"
    ),
    return_image: bool = Form(
        default=True,
        description="If true, returns image in response body. If false, returns only filepath."
    )
):
    """
    Edit an image based on text instruction
    
    Upload an image and provide an editing instruction. The API will:
    1. Preserve facial features and identity
    2. Apply the requested transformation
    3. Save the result to generated-images/api/
    4. Return the edited image
    
    **Examples:**
    - instruction: "Transform this person into Superman with cape and suit"
    - instruction: "Make this a professional headshot with business attire"
    - instruction: "Add sunglasses and a leather jacket"
    
    **Model Selection:**
    - 4-step: Ultra-fast (~20 seconds) - Good for testing
    - 8-step: Fast (~40 seconds) - Better quality
    - 40-step: Best quality (~3 minutes) - Production use
    
    **Note:** Switching models between requests takes several minutes.
    """
    try:
        # Validate model
        if model not in ["4-step", "8-step", "40-step"]:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid model: {model}. Must be one of: 4-step, 8-step, 40-step"
            )
        
        # Validate image format
        if image.content_type not in ["image/jpeg", "image/png", "image/jpg"]:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid image format: {image.content_type}. Must be JPEG or PNG"
            )
        
        # Read and open image
        image_data = await image.read()
        input_image = Image.open(io.BytesIO(image_data)).convert("RGB")
        
        # Generate edited image
        output_image, used_seed = pipeline_manager.generate_image(
            image=input_image,
            instruction=instruction,
            model_key=model,
            seed=seed,
            system_prompt=system_prompt
        )
        
        # Save image
        saved_path = save_image(output_image, model)
        
        # Prepare response
        if return_image:
            # Convert image to bytes
            img_byte_arr = io.BytesIO()
            output_image.save(img_byte_arr, format='PNG')
            img_byte_arr.seek(0)
            
            return Response(
                content=img_byte_arr.getvalue(),
                media_type="image/png",
                headers={
                    "X-Seed": str(used_seed),
                    "X-Model": model,
                    "X-Saved-Path": saved_path,
                    "Content-Disposition": f'attachment; filename="{Path(saved_path).name}"'
                }
            )
        else:
            return JSONResponse(
                content={
                    "success": True,
                    "filepath": saved_path,
                    "seed": used_seed,
                    "model": model,
                    "instruction": instruction
                }
            )
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
