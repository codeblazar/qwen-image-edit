# Instruction-Based Image Editing

## Overview

`qwen_instruction_edit.py` enables instruction-based image editing where you provide:
1. A seed image (person's face/pose)
2. An instruction (e.g., "Make me into Superman")
3. The model transforms the image while preserving facial features

## Quick Start

```powershell
# Activate virtual environment
.\.venv\Scripts\Activate.ps1

# Run with default example
python qwen_instruction_edit.py
```

## Configuration

Edit these variables in `qwen_instruction_edit.py`:

### 1. Seed Image
```python
# Local file or URL
seed_image_path = "path/to/your/image.jpg"
# or
seed_image_path = "https://example.com/image.jpg"
```

### 2. Instruction
```python
instruction = "Transform this character into Superman, wearing the iconic red and blue suit with cape"
```

### 3. System Prompt (Optional)

Create a `system_prompt.txt` file to apply global styling to ALL generations:

**Example system_prompt.txt:**
```
Create a photo-realistic, high-quality image with professional lighting and composition.
```

**Use cases:**
- Consistent artistic style: "Create in anime style"
- Quality control: "Professional photography, 8K resolution"
- Mood: "Dark and moody atmosphere"
- Constraints: "Maintain realistic proportions and anatomy"

**To disable:** Delete or rename `system_prompt.txt`

### 4. Other Parameters

```python
negative_prompt = "blurry, distorted face, low quality"  # What to avoid
num_steps = 4        # 4=ultra-fast, 8=better quality
seed = 0             # Change for variations
```

## Examples

### Superman Transformation
```python
instruction = "Transform into Superman with iconic suit and cape"
```

### Style Transfer
```python
instruction = "Transform into Studio Ghibli animation character"
```

### Costume Change
```python
instruction = "Dress as a 1940s detective with fedora and trench coat"
```

### Environment Change
```python
instruction = "Place in a futuristic cyberpunk city at night"
```

## Face Preservation

The script automatically adds face preservation guidance:
```python
prompt = f"{instruction}. Preserve the person's facial features, identity, and expression while applying the transformation."
```

**Pose handling:**
- Default: Preserves original pose
- Override: Include pose in instruction ("Superman flying through clouds")

## Tips

1. **Be specific** - "Superman costume" is better than "superhero"
2. **Set expectations** - "photo-realistic" vs "cartoon style" vs "oil painting"
3. **Iterate with seed** - Change seed value for different variations
4. **Quality vs Speed**:
   - `num_steps=4`: ~13 seconds, good quality
   - `num_steps=8`: ~26 seconds, better quality
   - `num_steps=40`: Use standard model for best quality

## Output Files

Generated images are saved as:
```
generated-images/instruct_{instruction_preview}_{timestamp}.png
```

Example:
```
generated-images/instruct_transform_this_character_int_20251002_143022.png
```

## Model Used

- **Base**: Lightning 4-step (svdq-int4_r128)
- **Speed**: ~13 seconds per image
- **Quality**: Good (suitable for rapid iteration)
- **VRAM**: ~23GB

## Troubleshooting

### Face not preserved
- Make instruction more specific
- Try seed=8 for higher quality
- Add to system_prompt.txt: "Maintain facial features exactly"

### Wrong style
- Be more specific in instruction
- Use system_prompt.txt for global style

### Poor quality
- Increase `num_steps` to 8
- Improve negative_prompt
- Check seed image quality

## Advanced Usage

### Batch Processing
Edit the script to loop through multiple instructions or seed images.

### Multiple Variations
```python
for seed in range(5):
    # Generate 5 variations
```

### Compare Models
Try the same instruction with:
- `qwen_instruction_edit.py` (4-step, fast)
- Modify to use 8-step model (balanced)
- Standard 40-step model (best quality)
