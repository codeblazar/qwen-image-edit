# File Naming Scheme Update

## ✅ Changes Applied

Updated the file naming scheme to clearly distinguish between API and Gradio UI generated images.

### New Naming Format

**API Generated Images:**
- Format: `qwen04-api_001.png`
- Pattern: `{model}-api_{number}.png`
- Location: `generated-images/api/`
- Examples:
  - `qwen04-api_001.png` (4-step model, first image)
  - `qwen08-api_042.png` (8-step model, 42nd image)
  - `qwen40-api_005.png` (40-step model, 5th image)

**Gradio UI Generated Images:**
- Format: `qwen04-gui_001.png`
- Pattern: `{model}-gui_{number}.png`
- Location: `generated-images/`
- Examples:
  - `qwen04-gui_001.png` (4-step model, first image)
  - `qwen08-gui_098.png` (8-step model, 98th image)
  - `qwen40-gui_012.png` (40-step model, 12th image)

### Files Modified

1. **`api/main.py`**
   - Updated `get_next_image_number()` to look for `-api_` pattern
   - Updated `save_image()` to create filenames with `-api_` suffix
   - Changed numbering format to 3 digits (001, 002, etc.)

2. **`qwen_gradio_ui.py`**
   - Updated `get_next_image_number()` to look for `-gui_` pattern
   - Updated filename generation to use `-gui_` suffix
   - Changed numbering format to 3 digits (001, 002, etc.)

3. **`api/README.md`**
   - Updated documentation to reflect new naming scheme
   - Added note explaining the distinction between `-api` and `-gui` suffixes

### Benefits

✅ **Clear Source Identification**: Easy to tell which interface generated each image
✅ **No Conflicts**: API and GUI numbering are completely independent
✅ **Better Organization**: Separate tracking for each interface
✅ **Consistent Format**: Both use 3-digit numbering (001-999)

### Migration Note

**Old files are not affected.** The new naming scheme only applies to newly generated images. Your existing files will remain unchanged:
- Old API files: `qwen04_0001.png`, `qwen04_0002.png`, etc.
- Old GUI files: `qwen04_0001.png`, `qwen08_0042.png`, etc.

The numbering system will start fresh with the new format:
- First new API image: `qwen04-api_001.png`
- First new GUI image: `qwen04-gui_001.png`

### Ready to Use

The changes are live! The next time you:
- Generate via API → Files will be named `qwen04-api_###.png`
- Generate via Gradio UI → Files will be named `qwen04-gui_###.png`

No server restart needed for the changes to take effect (though you may want to restart to be sure).
