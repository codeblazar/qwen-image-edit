"""
FastAPI REST API for Qwen Image Edit
Provides Swagger/OpenAPI interface for instruction-based image editing
"""
from fastapi import FastAPI, File, UploadFile, Form, HTTPException, Header, Depends, Query
from fastapi.responses import Response, JSONResponse
from PIL import Image
import io
import os
from datetime import datetime
from pathlib import Path
from typing import Optional, Literal

from models import ModelInfo, HealthResponse, JobSubmitResponse, JobStatusResponse, QueueStatusResponse
from pipeline_manager import PipelineManager
from job_queue import JobQueue, JobStatus
import asyncio


# Configuration Constants
MAX_IMAGE_SIZE_MB = 10  # Maximum upload size
MAX_IMAGE_DIMENSION = 2048  # Maximum width or height
MAX_INSTRUCTION_LENGTH = 500  # Maximum instruction text length
GENERATION_TIMEOUT_SECONDS = 300  # 5 minute timeout for generation
MODEL_LOAD_TIMEOUT_SECONDS = 180  # 3 minute timeout for model loading

# Queue Configuration (can be overridden with environment variables)
MAX_QUEUE_SIZE = int(os.getenv("MAX_QUEUE_SIZE", "10"))  # Maximum jobs in queue
QUEUE_CLEANUP_AGE = int(os.getenv("QUEUE_CLEANUP_AGE", "3600"))  # Cleanup age in seconds (default: 1 hour)

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

# Initialize job queue with configuration
job_queue = JobQueue(max_size=MAX_QUEUE_SIZE, cleanup_age_seconds=QUEUE_CLEANUP_AGE)

# Output directory for API-generated images
OUTPUT_DIR = Path("../generated-images/api")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


# Job Processing Callback
async def process_job_callback(job):
    """
    Callback function to process a job from the queue
    Called by the job queue worker when a job is ready to process
    """
    import io
    from PIL import Image
    
    try:
        # Convert bytes to PIL Image
        pil_image = Image.open(io.BytesIO(job.image_data)).convert("RGB")
        
        # Generate the image using pipeline manager
        result_image, actual_seed = await pipeline_manager.generate_image(
            image=pil_image,
            instruction=job.instruction,
            seed=job.seed,
            system_prompt=job.system_prompt
        )
        
        # Save the result
        result_path = save_image(result_image, job.model, actual_seed)
        
        # Mark job as completed
        job_queue.complete_job(job.job_id, result_path, actual_seed)
        
    except Exception as e:
        # Mark job as failed
        job_queue.fail_job(job.job_id, str(e))
        print(f"[JobQueue] Error processing job {job.job_id[:8]}: {e}")


# Startup and Shutdown Events
@app.on_event("startup")
async def startup_event():
    """Start the job queue on application startup"""
    job_queue.process_callback = process_job_callback
    job_queue.start()
    print("✅ Job queue started with processing callback")


@app.on_event("shutdown")
async def shutdown_event():
    """Stop the job queue on application shutdown"""
    await job_queue.stop()
    print("✅ Job queue stopped")


# API Key Configuration
# Reads from .api_key file (use manage-key.ps1 to manage)
def load_api_key():
    """Load API key from file or environment variable"""
    key_file = Path(__file__).parent / ".api_key"
    
    # Try to read from key file first
    if key_file.exists():
        with open(key_file, 'r') as f:
            return f.read().strip()
    
    # Fall back to environment variable
    key = os.getenv("QWEN_API_KEY")
    if key:
        return key
    
    # Default insecure key (should not be used in production)
    return "changeme-insecure-default-key"

API_KEY = load_api_key()

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


def save_image(image: Image.Image, model_key: str, seed: int) -> str:
    """Save image with timestamp and seed for uniqueness (prevents race conditions)"""
    import uuid
    
    # Map model key to prefix
    prefix_map = {
        "4-step": "qwen04",
        "8-step": "qwen08",
        "40-step": "qwen40"
    }
    prefix = prefix_map.get(model_key, "qwen")
    
    # Create unique filename with timestamp, seed, and UUID
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    unique_id = str(uuid.uuid4())[:8]
    filename = f"{prefix}_{timestamp}_s{seed}_{unique_id}.png"
    filepath = OUTPUT_DIR / filename
    
    # Save image with error handling
    try:
        image.save(filepath, format="PNG")
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to save image: {str(e)}. Check disk space and permissions."
        )
    
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
    """Health check endpoint with detailed state information"""
    return HealthResponse(
        status="healthy",
        current_model=pipeline_manager.current_model,
        model_loaded=pipeline_manager.pipeline is not None,
        is_loading=pipeline_manager.is_loading,
        is_generating=pipeline_manager.is_generating,
        queue_max_size=MAX_QUEUE_SIZE,
        queue_cleanup_age_seconds=QUEUE_CLEANUP_AGE
    )


@app.post("/api/v1/load-model", tags=["Model Management"], dependencies=[Depends(verify_api_key)])
async def load_model(
    model: Literal["4-step", "8-step", "40-step"] = Query(
        default="4-step",
        description="Model to load: 4-step (~20s), 8-step (~40s), or 40-step (~3min)"
    )
):
    """
    Load Model - Pre-loads a specific model into memory
    
    **IMPORTANT**: You must call this endpoint to load a model before using /edit.
    The loaded model will be used for all subsequent /edit requests until you load a different model.
    
    **Workflow:**
    1. Call `/load-model` with your desired model (4-step, 8-step, or 40-step)
    2. Wait for the model to load (first load takes ~1-2 minutes)
    3. Use `/edit` endpoint - it will use the currently loaded model
    4. To switch models, call `/load-model` again with a different model
    
    Args:
        model: Model to load (4-step, 8-step, or 40-step)
        
    Returns:
        Status, model info, and timing information
    """
    import time
    start = time.time()
    
    # Check if already busy
    if pipeline_manager.is_loading:
        raise HTTPException(
            status_code=409,
            detail="Model is already being loaded. Please wait for current operation to complete."
        )
    if pipeline_manager.is_generating:
        raise HTTPException(
            status_code=409,
            detail="Image generation in progress. Please wait for current operation to complete."
        )
    
    try:
        # Load the model with timeout
        pipeline = await asyncio.wait_for(
            pipeline_manager.load_model(model),
            timeout=MODEL_LOAD_TIMEOUT_SECONDS
        )
        
        elapsed = time.time() - start
        model_info = pipeline_manager.get_model_info(model)
        
        return {
            "status": "success",
            "message": f"Model '{model}' loaded and ready for image generation",
            "model": model,
            "model_name": model_info.get("name", model),
            "load_time_seconds": round(elapsed, 2),
            "estimated_generation_time": model_info.get("estimated_time", "unknown"),
            "note": "This model will be used for all /edit requests until you load a different model"
        }
    
    except asyncio.TimeoutError:
        raise HTTPException(
            status_code=504,
            detail=f"Model loading timed out after {MODEL_LOAD_TIMEOUT_SECONDS} seconds. Please try again."
        )
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


@app.post("/api/v1/submit", response_model=JobSubmitResponse, tags=["Job Queue"], dependencies=[Depends(verify_api_key)])
async def submit_job(
    image: UploadFile = File(..., description="Input image (JPG, PNG)"),
    instruction: str = Form(..., description="Editing instruction"),
    seed: Optional[int] = Form(default=None, description="Random seed"),
    system_prompt: Optional[str] = Form(default=None, description="Optional system prompt")
):
    """
    Submit an image editing job to the queue (RECOMMENDED for multiple stations)
    
    **Use this endpoint when:**
    - Multiple stations are calling the API
    - You want non-blocking job submission
    - You can poll for results later
    
    **Workflow:**
    1. Call `/submit` to queue your job → Returns `job_id`
    2. Poll `/status/{job_id}` to check progress
    3. When status = "completed", retrieve the result
    
    **Queue Limit:** Maximum 10 jobs in queue
    - Returns 429 Too Many Requests if queue is full
    - Jobs are processed in FIFO order
    
    **Response:**
    - `job_id`: Unique identifier for your job
    - `status`: "queued"
    - `position`: Your position in the queue (1 = next to process)
    - `estimated_wait_seconds`: Estimated time until processing starts
    """
    try:
        # Validate inputs (same as /edit endpoint)
        if len(instruction) > MAX_INSTRUCTION_LENGTH:
            raise HTTPException(
                status_code=400,
                detail=f"Instruction too long ({len(instruction)} chars). Maximum {MAX_INSTRUCTION_LENGTH} characters."
            )
        
        if image.content_type not in ["image/jpeg", "image/png", "image/jpg"]:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid image format: {image.content_type}. Must be JPEG or PNG"
            )
        
        image_data = await image.read()
        image_size_mb = len(image_data) / (1024 * 1024)
        
        if image_size_mb > MAX_IMAGE_SIZE_MB:
            raise HTTPException(
                status_code=400,
                detail=f"Image too large ({image_size_mb:.1f}MB). Maximum {MAX_IMAGE_SIZE_MB}MB allowed."
            )
        
        pil_image = Image.open(io.BytesIO(image_data)).convert("RGB")
        width, height = pil_image.size
        
        if width > MAX_IMAGE_DIMENSION or height > MAX_IMAGE_DIMENSION:
            raise HTTPException(
                status_code=400,
                detail=f"Image dimensions too large ({width}x{height}). Maximum {MAX_IMAGE_DIMENSION}x{MAX_IMAGE_DIMENSION} pixels."
            )
        
        # Check if model is loaded
        if pipeline_manager.current_model is None:
            raise HTTPException(
                status_code=400,
                detail="No model loaded. Please call /api/v1/load-model first to load a model."
            )
        
        # Submit job to queue
        try:
            job = await job_queue.submit_job(
                instruction=instruction,
                image_data=image_data,
                model=pipeline_manager.current_model,
                seed=seed,
                system_prompt=system_prompt
            )
            
            # Estimate wait time (rough estimate: position * avg_generation_time)
            avg_time_per_job = 30  # seconds (approximate for 4-step model)
            estimated_wait = (job.position - 1) * avg_time_per_job if job.position > 1 else 0
            
            return JobSubmitResponse(
                job_id=job.job_id,
                status="queued",
                position=job.position,
                message=f"Job queued successfully. Position: {job.position}",
                estimated_wait_seconds=estimated_wait if estimated_wait > 0 else None
            )
            
        except asyncio.QueueFull:
            raise HTTPException(
                status_code=429,
                detail=f"Queue is full (maximum {MAX_QUEUE_SIZE} jobs). Please try again later."
            )
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/status/{job_id}", response_model=JobStatusResponse, tags=["Job Queue"], dependencies=[Depends(verify_api_key)])
async def get_job_status(job_id: str):
    """
    Get the status of a submitted job
    
    **Job States:**
    - `queued`: Waiting in queue (check `position`)
    - `processing`: Currently being generated
    - `completed`: Done! Check `result_path` and `result_seed`
    - `failed`: Error occurred (check `error` field)
    
    **Polling Recommendation:**
    - Poll every 5-10 seconds while `status="queued"` or `"processing"`
    - Stop polling when `status="completed"` or `"failed"`
    """
    job = job_queue.get_job(job_id)
    
    if not job:
        raise HTTPException(
            status_code=404,
            detail=f"Job {job_id} not found. It may have been cleaned up (jobs are kept for 1 hour after completion)."
        )
    
    return JobStatusResponse(
        job_id=job.job_id,
        status=job.status.value,
        position=job.position if job.status == JobStatus.QUEUED else None,
        created_at=job.created_at,
        started_at=job.started_at,
        completed_at=job.completed_at,
        result_path=job.result_path,
        result_seed=job.result_seed,
        error=job.error,
        instruction=job.instruction,
        model=job.model
    )


@app.get("/api/v1/queue", response_model=QueueStatusResponse, tags=["Job Queue"], dependencies=[Depends(verify_api_key)])
async def get_queue_status():
    """
    Get current queue status
    
    Shows:
    - Current queue size and capacity
    - Number of jobs in each state
    - Currently processing job
    - Total jobs tracked
    
    Useful for monitoring queue health and capacity.
    """
    status = job_queue.get_queue_status()
    return QueueStatusResponse(**status)


@app.post("/api/v1/edit", tags=["Image Editing"], dependencies=[Depends(verify_api_key)])
async def edit_image(
    image: UploadFile = File(..., description="Input image (JPG, PNG)"),
    instruction: str = Form(..., description="Editing instruction (e.g., 'Make this person into Superman')"),
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
    Edit an image based on text instruction using the currently loaded model
    
    **IMPORTANT**: You must call `/load-model` first to load a model before using this endpoint.
    
    **Workflow:**
    1. Call `/load-model` with your desired model (4-step, 8-step, or 40-step)
    2. Use this `/edit` endpoint - it will use the currently loaded model
    3. To switch models, call `/load-model` again with a different model
    
    Upload an image and provide an editing instruction. The API will:
    1. Preserve facial features and identity
    2. Apply the requested transformation
    3. Save the result to generated-images/api/
    4. Return the edited image
    
    **Examples:**
    - instruction: "Transform this person into Superman with cape and suit"
    - instruction: "Make this a professional headshot with business attire"
    - instruction: "Add sunglasses and a leather jacket"
    
    **Available Models (load via /load-model):**
    - 4-step: Ultra-fast (~20 seconds) - Good for testing
    - 8-step: Fast (~40 seconds) - Better quality
    - 40-step: Best quality (~3 minutes) - Production use
    """
    try:
        # STEP 1: Validate inputs FIRST (before checking model state)
        # This gives better error messages and fails fast on bad input
        
        # Validate instruction length
        if len(instruction) > MAX_INSTRUCTION_LENGTH:
            raise HTTPException(
                status_code=400,
                detail=f"Instruction too long ({len(instruction)} chars). Maximum {MAX_INSTRUCTION_LENGTH} characters."
            )
        
        # Validate image format
        if image.content_type not in ["image/jpeg", "image/png", "image/jpg"]:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid image format: {image.content_type}. Must be JPEG or PNG"
            )
        
        # Read image data and validate size
        image_data = await image.read()
        image_size_mb = len(image_data) / (1024 * 1024)
        
        if image_size_mb > MAX_IMAGE_SIZE_MB:
            raise HTTPException(
                status_code=400,
                detail=f"Image too large ({image_size_mb:.1f}MB). Maximum {MAX_IMAGE_SIZE_MB}MB allowed."
            )
        
        # Open and validate image dimensions
        input_image = Image.open(io.BytesIO(image_data)).convert("RGB")
        width, height = input_image.size
        
        if width > MAX_IMAGE_DIMENSION or height > MAX_IMAGE_DIMENSION:
            raise HTTPException(
                status_code=400,
                detail=f"Image dimensions too large ({width}x{height}). Maximum {MAX_IMAGE_DIMENSION}x{MAX_IMAGE_DIMENSION} pixels."
            )
        
        # STEP 2: Check if a model is loaded
        if pipeline_manager.current_model is None:
            raise HTTPException(
                status_code=400,
                detail="No model loaded. Please call /api/v1/load-model first to load a model."
            )
        
        # STEP 3: Check if busy
        if pipeline_manager.is_loading:
            raise HTTPException(
                status_code=409,
                detail="Model is currently being loaded. Please wait for loading to complete."
            )
        if pipeline_manager.is_generating:
            raise HTTPException(
                status_code=409,
                detail="Another image is currently being generated. Please wait for it to complete."
            )
        
        # STEP 4: Generate edited image using currently loaded model with timeout
        output_image, used_seed = await asyncio.wait_for(
            pipeline_manager.generate_image(
                image=input_image,
                instruction=instruction,
                model_key=pipeline_manager.current_model,
                seed=seed,
                system_prompt=system_prompt
            ),
            timeout=GENERATION_TIMEOUT_SECONDS
        )
        
        # Save image using currently loaded model
        saved_path = save_image(output_image, pipeline_manager.current_model, used_seed)
        
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
                    "X-Model": pipeline_manager.current_model,
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
                    "model": pipeline_manager.current_model,
                    "instruction": instruction
                }
            )
    
    except asyncio.TimeoutError:
        raise HTTPException(
            status_code=504,
            detail=f"Image generation timed out after {GENERATION_TIMEOUT_SECONDS} seconds. Try a faster model or simpler instruction."
        )
    except HTTPException:
        # Re-raise HTTP exceptions as-is (don't convert to 500)
        raise
    except Exception as e:
        # Only catch unexpected exceptions and convert to 500
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
