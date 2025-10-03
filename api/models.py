"""
Pydantic models for API request/response validation
"""
from pydantic import BaseModel, Field
from typing import Literal, Optional


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
    """Health check response"""
    status: str
    current_model: Optional[str] = None
    model_loaded: bool
