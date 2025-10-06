# API Key Management

## Overview

The Qwen Image Edit API uses a **static API key** stored in `api/.api_key` file. This key persists across server restarts and can be rotated with a simple script.

## Key Management Script

Use `api/manage-key.ps1` to manage your API key:

### Generate a New Key

```powershell
.\api\manage-key.ps1 -Generate
```

### Show Current Key

```powershell
.\api\manage-key.ps1 -Show
```

Or simply:

```powershell
.\api\manage-key.ps1
```

### Rotate the Key

```powershell
.\api\manage-key.ps1 -Rotate
```

This will:
1. Log the old key as "Rotated (replaced)"
2. Generate and save a new key
3. Log the new key as "Rotated (new)"
4. Remind you to restart the API server and update clients

### View Key History

```powershell
.\api\manage-key.ps1 -History
```

This displays:
- All previously generated and rotated keys with timestamps
- The action taken (Generated, Rotated)
- The current active key highlighted at the bottom

Example output:
```
API Key History:
====================================================================================================

2025-10-06 14:23:15 [Generated] abc123...xyz789
2025-10-06 16:45:30 [Rotated (replaced)] abc123...xyz789
2025-10-06 16:45:30 [Rotated (new)] def456...uvw012

====================================================================================================
CURRENT ACTIVE KEY: def456...uvw012
```

## How It Works

1. **First Run**: When you start the API for the first time using `launch.ps1`, it automatically generates a key and saves it to `api/.api_key`

2. **Static Key**: The key is stored in a file and persists across:
   - Server restarts
   - Terminal sessions
   - System reboots

3. **Key Loading**: The API reads the key in this order:
   - From `api/.api_key` file (preferred)
   - From `QWEN_API_KEY` environment variable (fallback)
   - Default insecure key (development only)

## Security Best Practices

✅ **DO:**
- Keep the `.api_key` file secure
- Rotate keys periodically (monthly/quarterly)
- Use the rotation script before sharing access with new users
- Restart the API server after rotating keys

❌ **DON'T:**
- Commit `.api_key` to version control (already in .gitignore)
- Share the key in plain text (use secure channels)
- Use the default insecure key in production

## Key Rotation Workflow

1. **Schedule a maintenance window** (or just notify users of brief downtime)

2. **Rotate the key:**
   ```powershell
   .\api\manage-key.ps1 -Rotate
   ```

3. **Copy the new key** from the output

4. **Restart the API server:**
   ```powershell
   .\launch.ps1
   # Choose option 1
   ```

5. **Update all clients** with the new key

6. **Test the API** with the new key:
   ```bash
   curl -H "X-API-Key: YOUR-NEW-KEY" http://localhost:8000/api/v1/health
   ```

## File Location

The API key and history are stored at:
```
c:\Projects\qwen-image-edit\api\.api_key          # Current active key
c:\Projects\qwen-image-edit\api\.api_key_history  # Complete history log
```

### History File Format

The history file contains one entry per line:
```
YYYY-MM-DD HH:MM:SS | Action | Key
```

- **YYYY-MM-DD HH:MM:SS**: Timestamp when the key was generated/rotated
- **Action**: Either "Generated" or "Rotated (new)" or "Rotated (replaced)"
- **Key**: The actual API key

The **current active key** is always the **latest entry** with action "Generated" or "Rotated (new)".

## Troubleshooting

### Key not found

If you see "Invalid or missing API key":

1. Check if the file exists:
   ```powershell
   Test-Path .\api\.api_key
   ```

2. Regenerate if missing:
   ```powershell
   .\api\manage-key.ps1 -Generate
   ```

3. Restart the API server

### Key doesn't work after rotation

- Make sure you restarted the API server
- The server only reads the key file on startup
- Verify the key matches what's in the file:
  ```powershell
  .\api\manage-key.ps1 -Show
  ```
