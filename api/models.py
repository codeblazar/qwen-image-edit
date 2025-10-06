"""
Pydantic models for API request/response validation
"""
from pydantic import BaseModel, Field
from typing import Literal, Optional
from datetime import datetime


class ModelInfo(BaseModel):
    """Information about an available model"""
    name: str
    suffix: str
    steps: int
    cfg_scale: float
    estimated_time: str
    description: str


class EditRequest(BaseModel):
    """Request body for image editing (when using JSON instead of form)"""
    instruction: str = Field(..., description="Editing instruction (e.g., 'Make this person into Superman')")
    model: Literal["4-step", "8-step", "40-step"] = Field(
        default="4-step",
        description="Model to use: 4-step (20s), 8-step (40s), or 40-step (3min)"
    )
    seed: Optional[int] = Field(
        default=None,
        description="Random seed for reproducibility. If not provided, uses random seed."
    )
    system_prompt: Optional[str] = Field(
        default=None,
        description="Optional system prompt for styling (e.g., 'cinematic lighting, photorealistic')"
    )


class HealthResponse(BaseModel):
    """Health check response with operation state"""
    status: str
    current_model: Optional[str] = None
    model_loaded: bool
    is_loading: bool = False
    is_generating: bool = False
    queue_max_size: Optional[int] = None
    queue_cleanup_age_seconds: Optional[int] = None


class JobSubmitResponse(BaseModel):
    """Response when submitting a job to the queue"""
    job_id: str
    status: str = "queued"
    position: int
    message: str
    estimated_wait_seconds: Optional[int] = None


class JobStatusResponse(BaseModel):
    """Response for job status query"""
    job_id: str
    status: str  # queued, processing, completed, failed
    position: Optional[int] = None  # Only for queued jobs
    created_at: datetime
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    result_path: Optional[str] = None
    result_seed: Optional[int] = None
    error: Optional[str] = None
    instruction: str
    model: Optional[str] = None


class QueueStatusResponse(BaseModel):
    """Response for queue status query"""
    queue_size: int
    max_queue_size: int
    queued_count: int
    processing_count: int
    completed_count: int
    failed_count: int
    current_job_id: Optional[str] = None
    total_jobs: int

