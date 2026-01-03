"""
Pipeline manager for loading and managing Qwen image editing models
"""
import torch
from diffusers import QwenImageEditPlusPipeline
from nunchaku import NunchakuQwenImageTransformer2DModel
from nunchaku.utils import get_gpu_memory
from typing import Optional, Dict
import random
import time
from datetime import datetime
import asyncio
import os


class PipelineManager:
    """Manages model loading and caching for the API"""
    
    MODEL_CONFIGS = {
        "4-step": {
            "name": "Lightning 4-step (Ultra Fast)",
            "suffix": "lightningv2.0-4steps",
            "steps": 4,
            "cfg_scale": 1.0,
            "estimated_time": "~20 seconds",
            "description": "Ultra-fast generation with good quality"
        },
        "8-step": {
            "name": "Lightning 8-step (Fast)",
            "suffix": "lightningv2.0-8steps",
            "steps": 8,
            "cfg_scale": 1.0,
            "estimated_time": "~40 seconds",
            "description": "Fast generation with better quality"
        },
        "40-step": {
            "name": "Standard 40-step (Best Quality)",
            "suffix": "",
            "steps": 40,
            "cfg_scale": 4.0,
            "estimated_time": "~3 minutes",
            "description": "Best quality, slower generation"
        }
    }
    
    def __init__(self):
        self.pipeline: Optional[QwenImageEditPlusPipeline] = None
        self.transformer: Optional[NunchakuQwenImageTransformer2DModel] = None
        self.current_model: Optional[str] = None
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        
        # Thread safety: prevent concurrent model loading/generation
        self._model_lock = asyncio.Lock()
        self._generation_lock = asyncio.Lock()
        
        # Track operation state
        self.is_loading = False
        self.is_generating = False

        # Logging control (reduce console noise by default)
        # Levels: QUIET < INFO < DEBUG
        self._log_level = (os.getenv("QWEN_API_LOG_LEVEL") or "INFO").strip().upper()

    def _log(self, level: str, message: str) -> None:
        level = (level or "INFO").upper()
        order = {"QUIET": 0, "INFO": 1, "DEBUG": 2}
        current = order.get(self._log_level, 1)
        if order.get(level, 1) <= current:
            print(message)
    
    def get_model_info(self, model_key: str) -> Dict:
        """Get information about a specific model"""
        return self.MODEL_CONFIGS.get(model_key, {})
    
    def list_models(self) -> Dict[str, Dict]:
        """List all available models"""
        return self.MODEL_CONFIGS
    
    async def load_model(self, model_key: str = "4-step") -> QwenImageEditPlusPipeline:
        """
        Load the specified model. Caches the pipeline to avoid reloading.
        Thread-safe with async lock.
        
        Args:
            model_key: One of "4-step", "8-step", "40-step"
            
        Returns:
            Loaded pipeline
        """
        async with self._model_lock:
            if model_key not in self.MODEL_CONFIGS:
                raise ValueError(f"Invalid model: {model_key}. Must be one of {list(self.MODEL_CONFIGS.keys())}")
            
            # Return cached pipeline if it's the same model
            if self.current_model == model_key and self.pipeline is not None:
                self._log("INFO", f"[MODEL] '{model_key}' already loaded")
                return self.pipeline
            
            # Set loading state
            self.is_loading = True
            
            try:
                # Load new model
                await self._load_model_internal(model_key)
                return self.pipeline
            finally:
                self.is_loading = False
    
    async def _load_model_internal(self, model_key: str):
        """Internal method to actually load the model (runs in executor to avoid blocking)"""
        import asyncio
        loop = asyncio.get_event_loop()
        
        # Run the blocking model load in a thread pool
        await loop.run_in_executor(None, self._load_model_sync, model_key)
    
    def _load_model_sync(self, model_key: str):
        if self.pipeline is not None and self.current_model == model_key:
            self._log("INFO", f"[MODEL] Using cached '{model_key}'")
            return self.pipeline

        self._log("INFO", f"[MODEL] Loading '{model_key}'...")
        load_start = time.time()
        
        # Clear previous pipeline
        if self.pipeline is not None:
            self._log("DEBUG", f"[{datetime.now().strftime('%H:%M:%S.%f')[:-3]}] [INFO] Clearing previous model from memory...")
            del self.pipeline
            torch.cuda.empty_cache()
            self._log("DEBUG", f"[{datetime.now().strftime('%H:%M:%S.%f')[:-3]}] [OK] Previous model cleared")
        
        # Load new pipeline using nunchaku quantized models
        config = self.MODEL_CONFIGS[model_key]
        model_suffix = config["suffix"]
        
        # Build the safetensors filename (format: svdq-int4_r128-qwen-image-edit-2509-lightningv2.0-4steps.safetensors)
        if model_suffix:
            safetensors_file = f"svdq-int4_r128-qwen-image-edit-2509-{model_suffix}.safetensors"
        else:
            safetensors_file = "svdq-int4_r128-qwen-image-edit-2509.safetensors"
        
        self._log("DEBUG", f"[{datetime.now().strftime('%H:%M:%S.%f')[:-3]}] [INFO] Loading quantized transformer: {safetensors_file}")
        transformer_start = time.time()
        
        # Load quantized transformer
        self.transformer = NunchakuQwenImageTransformer2DModel.from_pretrained(
            f"nunchaku-tech/nunchaku-qwen-image-edit-2509/{safetensors_file}",
            torch_dtype=torch.bfloat16
        )
        
        transformer_time = time.time() - transformer_start
        self._log("DEBUG", f"[{datetime.now().strftime('%H:%M:%S.%f')[:-3]}] [OK] Transformer loaded in {transformer_time:.2f}s")

        self._log("DEBUG", f"[{datetime.now().strftime('%H:%M:%S.%f')[:-3]}] [INFO] Loading pipeline...")
        pipeline_start = time.time()
        
        # Load pipeline with quantized transformer
        self.pipeline = QwenImageEditPlusPipeline.from_pretrained(
            "Qwen/Qwen-Image-Edit-2509",
            transformer=self.transformer,
            torch_dtype=torch.bfloat16
        ).to(self.device)
        
        pipeline_time = time.time() - pipeline_start
        self._log("DEBUG", f"[{datetime.now().strftime('%H:%M:%S.%f')[:-3]}] [OK] Pipeline loaded in {pipeline_time:.2f}s")

        # Enable CPU offloading
        self._log("DEBUG", f"[{datetime.now().strftime('%H:%M:%S.%f')[:-3]}] [INFO] Configuring memory offloading...")
        offload_start = time.time()
        
        gpu_memory = get_gpu_memory()
        self._log("DEBUG", f"[{datetime.now().strftime('%H:%M:%S.%f')[:-3]}] [INFO] GPU Memory: {gpu_memory}GB")
        
        if gpu_memory > 18:
            self.pipeline.enable_model_cpu_offload()
            self._log("DEBUG", f"[{datetime.now().strftime('%H:%M:%S.%f')[:-3]}] [OK] Enabled model CPU offload")
            offload_mode = "model_cpu_offload"
        else:
            self.transformer.set_offload(True, use_pin_memory=False, num_blocks_on_gpu=1)
            self.pipeline._exclude_from_cpu_offload.append("transformer")
            self.pipeline.enable_sequential_cpu_offload()
            self._log("DEBUG", f"[{datetime.now().strftime('%H:%M:%S.%f')[:-3]}] [OK] Enabled sequential CPU offload")
            offload_mode = "sequential_cpu_offload"
        
        self.pipeline.set_progress_bar_config(disable=None)
        
        offload_time = time.time() - offload_start
        total_time = time.time() - load_start
        self._log(
            "INFO",
            f"[MODEL] Loaded '{model_key}' in {total_time:.2f}s (offload={offload_mode}, gpu_mem={gpu_memory}GB)",
        )

        # Only keep the detailed breakdown in DEBUG
        self._log("DEBUG", f"[{datetime.now().strftime('%H:%M:%S.%f')[:-3]}] [OK] Offloading configured in {offload_time:.2f}s")
        self._log("DEBUG", f"[{datetime.now().strftime('%H:%M:%S.%f')[:-3]}] [OK] TOTAL MODEL LOAD TIME: {total_time:.2f}s")
        
        self.current_model = model_key
        return self.pipeline
    
    async def generate_image(
        self,
        image,
        instruction: str,
        model_key: str = "4-step",
        seed: Optional[int] = None,
        system_prompt: Optional[str] = None
    ):
        """
        Generate edited image with concurrency protection
        
        Args:
            image: PIL Image object
            instruction: Editing instruction
            model_key: Model to use
            seed: Random seed (generates random if None)
            system_prompt: Optional system prompt for styling
            
        Returns:
            Tuple of (Generated PIL Image, seed used)
        """
        async with self._generation_lock:
            # Set generating state
            self.is_generating = True
            
            try:
                # Run generation in thread pool to avoid blocking
                loop = asyncio.get_event_loop()
                result = await loop.run_in_executor(
                    None,
                    self._generate_image_sync,
                    image,
                    instruction,
                    model_key,
                    seed,
                    system_prompt
                )
                return result
            finally:
                self.is_generating = False
    
    def _generate_image_sync(
        self,
        image,
        instruction: str,
        model_key: str,
        seed: Optional[int],
        system_prompt: Optional[str]
    ):
        """Synchronous image generation (called from thread pool)
        
        Returns:
            Tuple of (Generated PIL Image, seed used)
        """
        self._log("INFO", f"[GEN] Start (model={model_key})")
        generation_start = time.time()
        
        # Load model if needed (this is synchronous, but should already be loaded)
        if self.pipeline is None or self.current_model != model_key:
            raise RuntimeError(f"Model {model_key} not loaded. This should not happen - call load_model first.")
        
        pipeline = self.pipeline
        
        config = self.MODEL_CONFIGS[model_key]
        
        # Generate random seed if not provided
        if seed is None:
            seed = random.randint(0, 2**32 - 1)
        
        self._log("DEBUG", f"[{datetime.now().strftime('%H:%M:%S.%f')[:-3]}] [INFO] Using seed: {seed}")
        
        # Create generator with seed (matches Gradio UI approach)
        generator = torch.manual_seed(seed)
        
        # Sanitize instruction (remove leading/trailing quotes)
        instruction = instruction.strip().strip('"').strip("'")
        
        # Build full prompt with face preservation
        face_preservation = "Preserve the person's facial features, identity, and likeness exactly."
        
        if system_prompt:
            system_prompt = system_prompt.strip().strip('"').strip("'")
            full_prompt = f"{face_preservation} {system_prompt} {instruction}"
        else:
            full_prompt = f"{face_preservation} {instruction}"
        
        self._log("DEBUG", f"[{datetime.now().strftime('%H:%M:%S.%f')[:-3]}] [INFO] Prompt: {full_prompt[:100]}...")
        
        # Enhanced negative prompt for face preservation
        negative_prompt = (
            "distorted face, disfigured face, ugly face, deformed face, "
            "bad anatomy, extra limbs, missing limbs, blurry, low quality, "
            "watermark, text, signature"
        )
        
        # Generate image
        self._log("INFO", f"[GEN] Inference ({config['steps']} steps)...")
        inference_start = time.time()
        
        # Use inference mode for better performance (matches Gradio UI)
        with torch.inference_mode():
            result = pipeline(
                image=[image],  # Wrap in list to match Gradio UI format
                prompt=full_prompt,
                negative_prompt=negative_prompt,
                num_inference_steps=config["steps"],
                generator=generator,
                true_cfg_scale=config["cfg_scale"],
                num_images_per_prompt=1
            )
        
        inference_time = time.time() - inference_start
        total_time = time.time() - generation_start

        self._log("INFO", f"[GEN] Done in {total_time:.2f}s (inference={inference_time:.2f}s)")
        
        return result.images[0], seed
