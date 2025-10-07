# Test Script Changelog

## Version 2.0.3 (2025-10-07) - CURRENT

### Summary
Fixed critical PowerShell 7 multipart upload issue where images were sent as `application/octet-stream` instead of proper image content-types, causing API to reject all requests with 400 errors.

### Root Cause
PowerShell 7's `Invoke-RestMethod -Form` with `Get-Item` does not preserve file content-types, defaulting to `application/octet-stream`. The API server correctly validates content-types and only accepts `image/png`, `image/jpeg`, or `image/jpg`.

### The Fix
Unified implementation using `System.Net.Http.HttpClient` for **both** PowerShell 5.1 and 7+:
- Explicitly sets content-type based on file extension (`.png` → `image/png`, `.jpg`/`.jpeg` → `image/jpeg`)
- Works consistently across all PowerShell versions
- Properly handles multipart form data with correct MIME types

### Changes
- **Unified multipart upload**: Single code path using HttpClient for all PS versions
- **Enhanced error reporting**: Extracts actual API error messages from JSON responses
- **Debug logging**: Optional `-DebugLog` flag writes detailed request/response info to log file
- **Version tracking**: Displays script version and PowerShell version in test output
- **ASCII-only**: Removed all Unicode characters to prevent encoding issues

### Supported Image Formats
- **PNG** (`.png`) → `image/png`
- **JPEG** (`.jpg`, `.jpeg`) → `image/jpeg`
- Fallback: Unknown extensions default to `image/jpeg`

### Test Results
- ✅ All 14 tests pass locally (PowerShell 5.1 and 7+)
- ✅ All 14 tests pass remotely via Cloudflare tunnel
- ✅ Queue overflow protection working (10 accepted, 4-5 rejected with 429)
- ✅ Large image rejection working (400 error for >10MB)
- ✅ Proper content-type headers confirmed in debug logs

---

## Version History

### Version 2.0.2 (2025-10-07)
- Fixed PowerShell 7 error handling (attempted to use `.GetResponseStream()` which doesn't exist)
- Added proper `$_.ErrorDetails.Message` parsing for PS7+
- Still had the root content-type issue

### Version 2.0.1 (2025-10-07)
- Added debug logging capability
- Changed from `-Debug` to `-Verbose` to `-DebugLog` (avoiding PowerShell built-in parameters)
- Discovered the actual error message via enhanced logging

### Version 2.0.0 (2025-10-06)
- Enhanced error reporting
- Added version number display
- Fixed variable name issue (`$actualStatusCode:` → `${actualStatusCode}:`)
- Removed Unicode checkmarks causing parse errors
- Still using PowerShell 7's `-Form` parameter (which caused the issue)

### Earlier Versions
- Various fixes to queue handling, wait times, test prompts
- PowerShell 5.1 vs 7+ compatibility attempts
- PNG file extension issues

---

## Lessons Learned

1. **PowerShell `-Form` parameter is unreliable** for file content-types
   - Don't trust `Get-Item` to preserve MIME types
   - Always use HttpClient with explicit ContentType headers for multipart uploads

2. **Always validate with debug logging** when working cross-platform
   - Can't assume behavior is identical between PS versions
   - Debug logs reveal the actual HTTP requests/responses

3. **Unicode characters break PowerShell scripts** across different environments
   - Stick to ASCII-only for script code
   - Unicode OK for output strings only

4. **API validation is your friend**
   - Server correctly rejected invalid content-types
   - Proper error messages led to root cause

5. **Common parameters conflict**
   - Avoid `-Debug`, `-Verbose`, `-ErrorAction` etc. as custom parameters
   - Use unique names like `-DebugLog`
