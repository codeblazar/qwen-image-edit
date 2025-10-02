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

# Use rank 128 Lightning 4-step model for ultra-fast generation
rank = 128

print(f"Loading Nunchaku Lightning 4-step model (rank {rank})...")
print(f"Quantization: svdq-int4_r{rank}-lightningv2.0-4steps (~12.7GB)")
print("This ultra-fast Lightning model generates in ~10 seconds!")

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

print("\nDownloading input images...")
image1 = Image.open(BytesIO(requests.get("https://qianwen-res.oss-cn-beijing.aliyuncs.com/Qwen-Image/edit2509/edit2509_1.jpg").content))
image2 = Image.open(BytesIO(requests.get("https://qianwen-res.oss-cn-beijing.aliyuncs.com/Qwen-Image/edit2509/edit2509_2.jpg").content))
image1 = image1.convert("RGB")
image2 = image2.convert("RGB")
print("Images downloaded!")

prompt = "A stunning photo-realistic view of Sydney Harbour at golden hour, with the iconic Opera House gleaming in warm sunlight on the left and the Harbour Bridge spanning majestically across the sparkling blue water on the right, luxury yachts dotting the harbour."

inputs = {
    "image": [image1, image2],
    "prompt": prompt,
    "generator": torch.manual_seed(0),
    "true_cfg_scale": 1.0,  # Lightning models use 1.0 (not 4.0!)
    "negative_prompt": " ",
    "num_inference_steps": 4,  # Ultra-fast: Only 4 steps!
    "guidance_scale": 1.0,  # Match true_cfg_scale for Lightning
    "num_images_per_prompt": 1,
}

print("\nGenerating image with Lightning 4-step model...")
print(f"Prompt: {prompt}")
print(f"Inference steps: {inputs['num_inference_steps']} (Lightning 4-step - Ultra Fast!)")

with torch.inference_mode():
    output = pipeline(**inputs)
    output_image = output.images[0]
    
    # Save with timestamp and model identifier
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_path = f"generated-images/qwen-04_r{rank}_{timestamp}.png"
    output_image.save(output_path)
    print(f"\nSuccess! Lightning 4-step image saved at: {os.path.abspath(output_path)}")
    print(f"Generation completed with 4 steps (13.8x faster than standard 40 steps)")


