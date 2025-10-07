# API Test Scripts

This directory contains test scripts for the Qwen Image Edit API in both PowerShell (Windows) and Bash (macOS/Linux) formats.

## Required Files

Both test scripts require the following image files to be in the **same directory** as the scripts:

- `api-test-image.png` - Standard test image (512x512 pixels, ~1.3MB)
- `api-test-image-large.png` - Large test image for overflow testing (3000x3000 pixels, ~12.7MB)

**Important:** The scripts will check for these files at startup and exit with an error if they are missing.

## Bash Script (macOS/Linux) - `test-api-remote.sh`

### Prerequisites

- **bash** 3.2+ (included with macOS)
- **curl** (included with macOS)
- **jq** - JSON parser (install via: `brew install jq`)
- **bc** - Basic calculator for math operations (usually pre-installed)

### Setup

1. Remove quarantine attribute (macOS only):
   ```bash
   xattr -c test-api-remote.sh
   ```

2. Make the script executable:
   ```bash
   chmod 755 test-api-remote.sh
   ```

### Usage

```bash
./test-api-remote.sh [--debug|-d] <API_KEY> [BASE_URL]
```

**Examples:**

```bash
# Test against production server
./test-api-remote.sh "11qykWo0dzp8EscpTE4IjL7Fo0z3wl7vNwoYj1NAIY0"

# Test against local server
./test-api-remote.sh "your-api-key" "http://localhost:8000/api/v1"

# With debug logging
./test-api-remote.sh --debug "your-api-key"
# or
./test-api-remote.sh -d "your-api-key"
```

### Debug Logging

Enable debug logging with the `--debug` or `-d` flag:

```bash
./test-api-remote.sh --debug "your-api-key"
```

Debug output will be written to `test-api-remote-debug.log` in the same directory.

---

## PowerShell Script (Windows) - `test-api-remote.ps1`

### Prerequisites

- **PowerShell** 5.1 or higher (included with Windows 10+)
- No additional dependencies required

### Usage

```powershell
.\test-api-remote.ps1 <API_KEY> [BASE_URL] [-DebugLog]
```

**Examples:**

```powershell
# Test against production server
.\test-api-remote.ps1 "11qykWo0dzp8EscpTE4IjL7Fo0z3wl7vNwoYj1NAIY0"

# Test against local server
.\test-api-remote.ps1 "your-api-key" "http://localhost:8000/api/v1"

# With debug logging
.\test-api-remote.ps1 "your-api-key" -DebugLog
```

### Debug Logging

Enable debug logging with the `-DebugLog` flag:

```powershell
.\test-api-remote.ps1 "your-api-key" -DebugLog
```

Debug output will be written to `test-api-remote-debug.log` in the same directory.

---

## Test Coverage

Both scripts perform the following tests:

1. **Health Check** - Verify API is responding
2. **Invalid API Key Rejection** - Verify authentication is working
3. **List Available Models** - Test model enumeration
4. **Get Queue Status** - Test queue status endpoint
5. **Load Model** - Test model loading (4-step model)
6. **Submit Image Editing Job** - Test basic job submission
7. **Check Job Status** - Test job status tracking
8. **Wait for Completion** - Test job completion workflow
9. **Submit Multiple Jobs** - Test concurrent job handling
10. **Queue Overflow Protection** - Test queue limits (submit 15 jobs, expect 10 accepted + 5 rejected)
11. **Queue Status Under Load** - Verify queue reporting under load
12. **Queue Position Tracking** - Test job position updates
13. **Reject Oversized Image** - Test file size/dimension limits
14. **Invalid Job ID** - Test error handling for non-existent jobs

## Expected Results

- **Total Tests:** 14
- **Pass Rate:** 100% (14/14)
- **Test Duration:** ~3-5 minutes (depending on queue processing time)

## Troubleshooting

### Missing Test Images

If you see this error:
```
[ERROR] Required test image not found: /path/to/api-test-image.png
[ERROR] Please ensure 'api-test-image.png' (512x512) is in the same directory as this script.
```

**Solution:** Copy both `api-test-image.png` and `api-test-image-large.png` to the same directory as the test script.

### API Key Issues

If you see authentication failures:
- Verify your API key is correct
- Check that the API server is running
- Ensure the API key file (`.api_key`) exists on the server

### Server Not Ready

If the script reports "Server not ready":
- Check that the API server is running
- Verify the BASE_URL is correct
- Check network connectivity (firewall, VPN, etc.)

### Queue Tests Failing

If queue overflow tests fail:
- The server may be processing jobs very quickly
- This is usually not an error - check the test output for warnings
- Debug logging can help identify if jobs are being accepted/rejected correctly

## Notes

- Both scripts have **identical functionality**
- Queue drain shows real-time progress (completed jobs / total jobs)
- Debug logging captures full request/response details for troubleshooting
- Scripts automatically clean up temporary test images
- Color-coded output: Green (pass), Red (fail), Cyan (info), Yellow (warning)

## Version

Current Version: **2.0.3** (2025-10-07)

See `TEST_SCRIPT_CHANGELOG.md` for complete version history and changes.
