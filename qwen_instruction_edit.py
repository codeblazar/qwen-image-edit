import os
import torch
from PIL import Image
from diffusers import QwenImageEditPlusPipeline
from io import BytesIO
import requests
from datetime import datetime
from nunchaku import NunchakuQwenImageTransformer2DModel
from nunchaku.utils import get_gpu_memory, get_precision

# Create output directory if it doesn't exist
os.makedirs("generated-images", exist_ok=True)

# Use rank 128 Lightning 4-step model for fast iteration
rank = 128

print(f"Loading Nunchaku Lightning 4-step model for instruction-based editing (rank {rank})...")
print(f"Quantization: svdq-int4_r{rank}-lightningv2.0-4steps (~12.7GB)")
print("Ultra-fast instruction-based image editing!")

# Load the quantized Lightning 4-step transformer
transformer = NunchakuQwenImageTransformer2DModel.from_pretrained(
    f"nunchaku-tech/nunchaku-qwen-image-edit-2509/svdq-{get_precision()}_r{rank}-qwen-image-edit-2509-lightningv2.0-4steps.safetensors"
)
print("Lightning 4-step transformer loaded!")

# Load the pipeline with the quantized transformer
pipeline = QwenImageEditPlusPipeline.from_pretrained(
    "Qwen/Qwen-Image-Edit-2509", 
    transformer=transformer, 
    torch_dtype=torch.bfloat16
)
print("Pipeline loaded!")

# Memory management for RTX 4090 (24GB)
gpu_memory = get_gpu_memory()
print(f"GPU Memory: {gpu_memory}GB")

if gpu_memory > 18:
    print("Using model CPU offload (enough VRAM available)")
    pipeline.enable_model_cpu_offload()
else:
    print("Using per-layer offloading for low VRAM")
    transformer.set_offload(True, use_pin_memory=False, num_blocks_on_gpu=1)
    pipeline._exclude_from_cpu_offload.append("transformer")
    pipeline.enable_sequential_cpu_offload()

pipeline.set_progress_bar_config(disable=None)

print("\n" + "="*80)
print("INSTRUCTION-BASED IMAGE EDITING")
print("="*80)

# =============================================================================
# SYSTEM PROMPT (Optional)
# =============================================================================
# Load system prompt from file if it exists
# This will be prepended to ALL instructions
system_prompt = ""
system_prompt_file = "system_prompt.txt"

if os.path.exists(system_prompt_file):
    with open(system_prompt_file, 'r', encoding='utf-8') as f:
        system_prompt = f.read().strip()
    print(f"\n📋 System prompt loaded from {system_prompt_file}")
    print(f"   Preview: {system_prompt[:100]}...")
else:
    print(f"\n📋 No system prompt file found (optional: create {system_prompt_file})")

# =============================================================================
# USER CONFIGURATION - EDIT THIS SECTION
# =============================================================================

# Input seed image (local file path or URL)
seed_image_path = "https://qianwen-res.oss-cn-beijing.aliyuncs.com/Qwen-Image/edit2509/edit2509_1.jpg"

# Instruction prompt - what you want to do with the image
instruction = "Transform this character into Superman, wearing the iconic red and blue suit with cape, maintaining their facial features and expression"

# Optional: Provide negative prompt to avoid unwanted elements
negative_prompt = "blurry, distorted face, low quality, deformed, disfigured"

# Number of inference steps (4 for ultra-fast, 8 for better quality)
num_steps = 4

# Random seed for reproducibility (change for different variations)
seed = 0

# =============================================================================
# END USER CONFIGURATION
# =============================================================================

print(f"\n📸 Seed Image: {seed_image_path}")
print(f"✍️  Instruction: {instruction}")
print(f"⚡ Steps: {num_steps}")
print(f"🎲 Seed: {seed}")

# Load seed image
print("\nLoading seed image...")
if seed_image_path.startswith("http://") or seed_image_path.startswith("https://"):
    seed_image = Image.open(BytesIO(requests.get(seed_image_path).content))
else:
    seed_image = Image.open(seed_image_path)
seed_image = seed_image.convert("RGB")
print("Seed image loaded!")

# Craft the prompt for instruction-based editing
# Combine system prompt (if any) + instruction + face preservation
if system_prompt:
    prompt = f"{system_prompt} {instruction}. Preserve the person's facial features, identity, and expression while applying the transformation."
else:
    prompt = f"{instruction}. Preserve the person's facial features, identity, and expression while applying the transformation."

inputs = {
    "image": [seed_image],  # Single image for instruction-based editing
    "prompt": prompt,
    "generator": torch.manual_seed(seed),
    "true_cfg_scale": 1.0,  # Lightning models use 1.0
    "negative_prompt": negative_prompt,
    "num_inference_steps": num_steps,
    "guidance_scale": 1.0,
    "num_images_per_prompt": 1,
}

print("\n" + "="*80)
print("GENERATING...")
print("="*80)
print(f"Full Prompt: {prompt}")
print(f"Negative: {negative_prompt}")

with torch.inference_mode():
    output = pipeline(**inputs)
    output_image = output.images[0]
    
    # Save with timestamp and instruction identifier
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    # Create safe filename from instruction (first 30 chars, replace spaces)
    safe_instruction = instruction[:30].replace(" ", "_").replace(",", "").lower()
    output_path = f"generated-images/instruct_{safe_instruction}_{timestamp}.png"
    output_image.save(output_path)
    
    print("\n" + "="*80)
    print("✅ SUCCESS!")
    print("="*80)
    print(f"📁 Saved to: {os.path.abspath(output_path)}")
    print(f"⏱️  Generation: {num_steps} steps (ultra-fast instruction-based editing)")
    print("\nTo generate variations:")
    print("  - Change 'seed' value for different results")
    print("  - Adjust 'instruction' for different transformations")
    print("  - Try num_steps=8 for higher quality (slower)")
