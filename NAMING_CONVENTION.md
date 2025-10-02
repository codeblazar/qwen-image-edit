# File Naming Convention

## Generated Image Names

All generated images follow a simple, clean naming pattern:

```
generated-images/{model}_{number}.png
```

### Format

- **Model prefix**: Identifies which model generated the image
  - `qwen04` - Lightning 4-step model (ultra-fast)
  - `qwen08` - Lightning 8-step model (balanced)
  - `qwen40` - Standard 40-step model (best quality)

- **Sequential number**: 4-digit zero-padded number
  - Automatically increments for each model independently
  - Starts at `0001`

### Examples

```
qwen04_0001.png  - First image from 4-step model
qwen04_0002.png  - Second image from 4-step model
qwen08_0001.png  - First image from 8-step model
qwen08_0042.png  - 42nd image from 8-step model
qwen40_0001.png  - First image from 40-step model
```

### Benefits

- ✅ **Short & clean** - Easy to read and type
- ✅ **Sortable** - Files naturally sort by model then sequence
- ✅ **Unique** - Each model has its own sequence
- ✅ **Sequential** - Easy to track how many images generated per model
- ✅ **No timestamps** - Cleaner filenames (creation date still in file metadata)

### Finding Images

```powershell
# List all 4-step images
ls generated-images/qwen04_*.png

# List all 8-step images
ls generated-images/qwen08_*.png

# List all 40-step images
ls generated-images/qwen40_*.png

# Count images per model
(ls generated-images/qwen04_*.png).Count
(ls generated-images/qwen08_*.png).Count
(ls generated-images/qwen40_*.png).Count
```

### Notes

- Numbers increment independently for each model
- If you delete a file, that number won't be reused
- The system always uses the highest existing number + 1
