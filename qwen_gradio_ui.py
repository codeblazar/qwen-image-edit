import os
import torch
import random
import glob
from PIL import Image
from diffusers import QwenImageEditPlusPipeline
from datetime import datetime
from nunchaku import NunchakuQwenImageTransformer2DModel
from nunchaku.utils import get_gpu_memory, get_precision
import gradio as gr

print("="*80)
print("QWEN INSTRUCTION-BASED IMAGE EDITING - WEB UI")
print("="*80)

# Create output directory if it doesn't exist
os.makedirs("generated-images", exist_ok=True)

# Model configurations
MODEL_CONFIGS = {
    "Lightning 4-step (Ultra Fast ~10s)": {
        "model_suffix": "lightningv2.0-4steps",
        "steps": 4,
        "true_cfg_scale": 1.0,
        "description": "Ultra-fast generation, good quality"
    },
    "Lightning 8-step (Fast ~20s)": {
        "model_suffix": "lightningv2.0-8steps",
        "steps": 8,
        "true_cfg_scale": 1.0,
        "description": "Balanced speed and quality"
    },
    "Standard 40-step (Best Quality ~2:45)": {
        "model_suffix": "",
        "steps": 40,
        "true_cfg_scale": 4.0,
        "description": "Highest quality, slower generation"
    }
}

# Cache for loaded pipelines
pipelines_cache = {}
rank = 128

def load_pipeline(model_choice, progress_callback=None):
    """
    Load or retrieve cached pipeline for the selected model
    """
    if model_choice in pipelines_cache:
        if progress_callback:
            progress_callback(0.1, desc="Using cached model...")
        return pipelines_cache[model_choice]
    
    config = MODEL_CONFIGS[model_choice]
    
    if progress_callback:
        progress_callback(0.1, desc=f"Loading {model_choice}...")
    
    print(f"\nLoading {model_choice}...")
    print(f"Quantization: svdq-int4_r{rank} (~12.7GB)")
    
    # Determine model path
    if config["model_suffix"]:
        model_path = f"nunchaku-tech/nunchaku-qwen-image-edit-2509/svdq-{get_precision()}_r{rank}-qwen-image-edit-2509-{config['model_suffix']}.safetensors"
    else:
        model_path = f"nunchaku-tech/nunchaku-qwen-image-edit-2509/svdq-{get_precision()}_r{rank}-qwen-image-edit-2509.safetensors"
    
    # Load transformer
    transformer = NunchakuQwenImageTransformer2DModel.from_pretrained(model_path)
    print("✓ Transformer loaded!")
    
    # Load pipeline
    pipeline = QwenImageEditPlusPipeline.from_pretrained(
        "Qwen/Qwen-Image-Edit-2509", 
        transformer=transformer, 
        torch_dtype=torch.bfloat16
    )
    print("✓ Pipeline loaded!")
    
    # Memory management
    gpu_memory = get_gpu_memory()
    print(f"✓ GPU Memory: {gpu_memory}GB")
    
    if gpu_memory > 18:
        pipeline.enable_model_cpu_offload()
    else:
        transformer.set_offload(True, use_pin_memory=False, num_blocks_on_gpu=1)
        pipeline._exclude_from_cpu_offload.append("transformer")
        pipeline.enable_sequential_cpu_offload()
    
    pipeline.set_progress_bar_config(disable=None)
    
    # Cache the pipeline
    pipelines_cache[model_choice] = pipeline
    
    print(f"✓ {model_choice} ready!\n")
    
    return pipeline

print("\n" + "="*80)
print("✅ INTERFACE READY! Models will load on-demand...")
print("="*80 + "\n")

def generate_random_seed():
    """
    Generate a random seed for image generation
    Range: 0 to 2^32-1 (4,294,967,295) - standard range for torch.manual_seed
    """
    return random.randint(0, 2**32 - 1)

def get_next_image_number(model_prefix):
    """
    Get the next sequential number for the given model prefix
    Returns the next available number based on existing files
    """
    # Find all files matching the pattern
    pattern = f"generated-images/{model_prefix}_*.png"
    existing_files = glob.glob(pattern)
    
    if not existing_files:
        return 1
    
    # Extract numbers from filenames
    numbers = []
    for filepath in existing_files:
        filename = os.path.basename(filepath)
        # Extract number from pattern like "qwen04_0001.png"
        parts = filename.replace(".png", "").split("_")
        if len(parts) >= 2:
            try:
                numbers.append(int(parts[-1]))
            except ValueError:
                continue
    
    # Return next number
    return max(numbers) + 1 if numbers else 1

def sanitize_text(text):
    """
    Remove or replace problematic characters that might cause issues
    """
    if not text:
        return text
    
    # Replace smart quotes with regular quotes
    text = text.replace('"', '"').replace('"', '"')
    text = text.replace(''', "'").replace(''', "'")
    
    # Remove null bytes
    text = text.replace('\x00', '')
    
    # Strip whitespace first
    text = text.strip()
    
    # Remove leading/trailing quotes that might cause issues
    # This handles cases where users wrap entire prompt in quotes
    while text and text[0] in ['"', "'"]:
        text = text[1:]
    while text and text[-1] in ['"', "'"]:
        text = text[:-1]
    
    return text.strip()

def generate_image(
    seed_image,
    reference_image,
    instruction,
    system_prompt,
    negative_prompt,
    model_choice,
    seed,
    progress=gr.Progress()
):
    """
    Generate instruction-based edited image with optional reference image
    """
    try:
        progress(0, desc="Preparing...")
        
        # Load and convert seed image
        if seed_image is None:
            return None, "❌ Please upload a seed image!"
        
        seed_img = Image.fromarray(seed_image).convert("RGB")
        
        # Prepare images list - add reference image if provided
        images_list = [seed_img]
        reference_note = ""
        
        if reference_image is not None:
            ref_img = Image.fromarray(reference_image).convert("RGB")
            images_list.append(ref_img)
            reference_note = " Using reference image for pose/style/background guidance."
        
        # Sanitize text inputs to avoid issues with special characters
        instruction = sanitize_text(instruction)
        system_prompt = sanitize_text(system_prompt) if system_prompt else ""
        negative_prompt = sanitize_text(negative_prompt) if negative_prompt else ""
        
        # Craft the full prompt with STRONG face preservation
        # Face preservation comes FIRST for maximum emphasis
        face_preservation = "IMPORTANT: Keep the person's exact face, facial features, identity, likeness, and expression identical to the seed image. Maintain facial structure perfectly."
        
        if system_prompt and system_prompt.strip():
            full_prompt = f"{face_preservation} {system_prompt.strip()} {instruction}"
        else:
            full_prompt = f"{face_preservation} {instruction}"
        
        # Enhance negative prompt with face-specific terms
        enhanced_negative = negative_prompt
        if enhanced_negative:
            enhanced_negative += ", changed face, different person, face swap, altered facial features, wrong identity"
        else:
            enhanced_negative = "changed face, different person, face swap, altered facial features, wrong identity, blurry face, distorted face, deformed face"
        
        # Load the selected model (cached after first load)
        pipeline = load_pipeline(model_choice, progress)
        config = MODEL_CONFIGS[model_choice]
        
        progress(0.3, desc="Generating image...")
        
        # Prepare inputs with model-specific settings
        inputs = {
            "image": images_list,  # Can be single image or [seed, reference]
            "prompt": full_prompt,
            "generator": torch.manual_seed(seed),
            "true_cfg_scale": config["true_cfg_scale"],
            "negative_prompt": enhanced_negative,
            "num_inference_steps": config["steps"],
            "guidance_scale": 1.0,
            "num_images_per_prompt": 1,
        }
        
        # Generate
        with torch.inference_mode():
            output = pipeline(**inputs)
            output_image = output.images[0]
        
        progress(0.9, desc="Saving...")
        
        # Determine model prefix based on steps
        if config["steps"] == 4:
            model_prefix = "qwen04"
        elif config["steps"] == 8:
            model_prefix = "qwen08"
        else:  # 40 steps
            model_prefix = "qwen40"
        
        # Get next sequential number for this model
        image_number = get_next_image_number(model_prefix)
        
        # Save with simple sequential naming: qwen04_0001.png, qwen08_0042.png, etc.
        output_path = f"generated-images/{model_prefix}_{image_number:04d}.png"
        output_image.save(output_path)
        
        progress(1.0, desc="Complete!")
        
        info = f"""✅ **Generation Complete!**{reference_note}
        
📁 **Saved to:** `{output_path}`
🎨 **Model:** {model_choice}
⏱️ **Steps:** {config['steps']} | CFG Scale: {config['true_cfg_scale']}
🎲 **Seed:** {seed} (save this to recreate exact result!)
📝 **Full Prompt:** {full_prompt[:150]}...

💡 **Tip:** Click 🎲 Randomize for a new variation, or note the seed number to recreate this exact image!
"""
        
        return output_image, info
        
    except Exception as e:
        return None, f"❌ Error: {str(e)}"

# Load system prompt examples
system_prompt_examples = [
    "",  # Empty (no system prompt)
    "Create a photo-realistic, high-quality image with professional lighting and composition.",
    "Create in anime art style with vibrant colors and expressive features.",
    "Create in Studio Ghibli animation style with soft colors and whimsical atmosphere.",
    "Professional studio photography, 8K resolution, perfect lighting, sharp focus.",
    "Create as a classical oil painting with visible brushstrokes and rich colors.",
    "Futuristic cyberpunk aesthetic with neon lights and dystopian atmosphere.",
    "Comic book art style with bold lines, vibrant colors, and dynamic composition.",
]

instruction_examples = [
    "Transform this character into Superman, wearing the iconic red and blue suit with cape",
    "Make this person look like a 1940s detective with fedora and trench coat",
    "Transform into a Studio Ghibli character in a magical forest",
    "Make this person into a cyberpunk hacker with neon lights",
    "Transform into a medieval knight with armor and sword",
    "Make this person look like a Disney princess in a ball gown",
    "Transform into a Star Wars Jedi with lightsaber",
    "Make this person into a pirate captain with tricorn hat",
]

# Create Gradio interface
with gr.Blocks(title="Qwen Instruction-Based Image Editing", theme=gr.themes.Soft()) as demo:
    gr.Markdown("""
    # 🎨 Qwen Instruction-Based Image Editing
    
    Transform people in images with text instructions while preserving their identity!
    
    **How to use:**
    1. Upload a seed image (photo of a person)
    2. Optionally upload a reference image (for pose, body shape, background, or items to combine)
    3. Write an instruction (what you want to transform)
    4. Optionally add a system prompt (global style)
    5. Click Generate!
    """)
    
    with gr.Row():
        with gr.Column(scale=1):
            gr.Markdown("### 📸 Input")
            
            seed_image = gr.Image(
                label="Seed Image (Main person/subject)",
                type="numpy",
                height=300
            )
            
            reference_image = gr.Image(
                label="Reference Image (Optional - for pose/body/background/items)",
                type="numpy",
                height=300
            )
            
            instruction = gr.Textbox(
                label="Instruction",
                placeholder="e.g., Transform this character into Superman...",
                lines=3,
                value="Transform this character into Superman, wearing the iconic red and blue suit with cape, maintaining their facial features and expression"
            )
            
            gr.Markdown("**Instruction Examples:**")
            gr.Examples(
                examples=instruction_examples,
                inputs=instruction,
                label=None
            )
            
            # Model selection - prominent placement
            model_choice = gr.Radio(
                label="⚡ Model Selection",
                choices=list(MODEL_CONFIGS.keys()),
                value="Lightning 4-step (Ultra Fast ~10s)",
                info="Choose speed vs quality tradeoff"
            )
            
            with gr.Accordion("⚙️ Advanced Settings", open=False):
                system_prompt = gr.Textbox(
                    label="System Prompt (Optional - applies to all generations)",
                    placeholder="e.g., Create a photo-realistic, high-quality image...",
                    lines=2,
                    value="Create a photo-realistic, high-quality image with professional lighting and composition."
                )
                
                gr.Markdown("**System Prompt Presets:**")
                gr.Examples(
                    examples=system_prompt_examples,
                    inputs=system_prompt,
                    label=None
                )
                
                negative_prompt = gr.Textbox(
                    label="Negative Prompt (what to avoid)",
                    value="changed face, different person, face swap, altered facial features, blurry face, distorted face, low quality, deformed, disfigured",
                    lines=3
                )
                
                with gr.Row():
                    seed = gr.Number(
                        label="Seed (Random by default)",
                        value=generate_random_seed(),
                        precision=0,
                        info="Each seed gives consistent results",
                        scale=3
                    )
                    
                    randomize_seed_btn = gr.Button("🎲 Randomize", scale=1)
            
            generate_btn = gr.Button("✨ Generate", variant="primary", size="lg")
        
        with gr.Column(scale=1):
            gr.Markdown("### 🖼️ Output")
            
            output_image = gr.Image(
                label="Generated Image",
                type="pil",
                format="png",  # Ensure PNG format for downloads (WebP is fine for display)
                height=400,
                show_download_button=True
            )
            
            output_info = gr.Markdown()
    
    # Connect the randomize seed button
    randomize_seed_btn.click(
        fn=lambda: generate_random_seed(),
        outputs=seed
    )
    
    # Connect the generate button
    generate_btn.click(
        fn=generate_image,
        inputs=[seed_image, reference_image, instruction, system_prompt, negative_prompt, model_choice, seed],
        outputs=[output_image, output_info]
    )
    
    gr.Markdown("""
    ---
    ### 💡 Tips
    
    - **Face Preservation**: AUTOMATIC across ALL models - Face preservation enforced with model-specific settings:
      - Lightning models (4/8-step): `true_cfg_scale=1.0` + strong face prompts
      - Standard model (40-step): `true_cfg_scale=4.0` + strong face prompts
      - If losing identity: Try clearer seed image or click 🎲 Randomize seed
    - **Reference Image**: Upload a second image to use as reference for:
      - **Pose**: "Match the pose from the reference image"
      - **Body Shape**: "Use the body type from the reference image"
      - **Background**: "Place in the background/scene from the reference image"
      - **Items/Objects**: "Include the [item] from the reference image"
      - **Combination**: "Combine elements from both images"
    - **Random Seeds**: Each generation uses a RANDOM seed by default for variety
      - Click 🎲 Randomize to get a new random seed
      - Note a specific seed number to recreate exact results later
    - **Pose Changes**: Include pose instructions in your prompt (e.g., "Superman flying")
    - **Model Selection**: Switch anytime - settings auto-adjust for each model
      - **Lightning 4-step**: Ultra-fast (~10s), great for experimentation
      - **Lightning 8-step**: Balanced (~20s), better quality
      - **Standard 40-step**: Best quality (~2:45), production use
    - **System Prompt**: Apply consistent styling to all generations (optional)
    - **First Load**: Each model downloads once (~12.7GB), then cached for instant reuse
    
    ### 📝 Examples
    
    - "Make me into Superman" → Costume transformation
    - "Transform into Studio Ghibli character" → Style transfer
    - "Match the pose from the reference image" → Pose transfer
    - "Place in the background from the reference image" → Background replacement
    - "Dress as 1940s detective" → Time period change
    - "Combine my face with the body pose from the reference image" → Pose + face combo
    
    ### ⚠️ Note
    
    All generated images are saved to `generated-images/` folder with timestamps.
    """)

# Launch the interface
if __name__ == "__main__":
    demo.launch(
        share=False,
        server_name="127.0.0.1",
        server_port=7860,
        show_error=True
    )
