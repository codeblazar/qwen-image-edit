# Qwen Tunnel Status - November 6, 2025

## What's Working ✓

1. **API Server**: Running perfectly on port 8000
   - Local Swagger UI: http://localhost:8000/docs
   - Local Health: http://localhost:8000/api/v1/health
   - Response: `{"status":"healthy","current_model":null,"model_loaded":false,...}`

2. **Cloudflare Tunnel**: Connected with 4 edge servers
   - Tunnel ID: `40bf02b9-fc37-46c4-a849-d6660c0aed6f`
   - Connector: `04e27410-fdd3-4928-9329-f5e773fbb954`
   - Edge locations: sin13, sin15, sin16, sin21
   - Configuration file: `C:\Users\petek\.cloudflared\config.yml`

3. **DNS**: Resolves correctly
   - `qwen.codeblazar.org` → Cloudflare IPs (104.21.43.79, 172.67.175.185)

4. **Launch Scripts**: Working perfectly
   - `launch-simple.ps1` - Clean launcher without Unicode issues
   - `tunnel-debug.ps1` - Diagnostic tool

## What's NOT Working ✗

**Public URL returns Error 1033** (Argo Tunnel error)
- URL: https://qwen.codeblazar.org/api/v1/health
- Error: "error code: 1033" or "530"
- Cause: Tunnel is connected but Cloudflare routing is not configured

## Root Cause

The tunnel is running and connected, BUT the Cloudflare dashboard doesn't have the public hostname route configured.

## How to Fix

### Option 1: Via Cloudflare Zero Trust Dashboard (Recommended)

1. Go to: https://one.dash.cloudflare.com/
2. Navigate to: **Networks** > **Tunnels**
3. Find tunnel: **qwen** (ID: 40bf02b9...)
4. Click **Configure**
5. Go to **Public Hostname** tab
6. Add/verify route:
   - **Subdomain**: `qwen`
   - **Domain**: `codeblazar.org`
   - **Service Type**: `HTTP`
   - **URL**: `localhost:8000`

7. Save and wait 30 seconds

### Option 2: Via Command Line

```powershell
cloudflared tunnel route dns qwen qwen.codeblazar.org
```

## Test After Fixing

```powershell
# Wait 30 seconds after configuring, then test
.\tunnel-debug.ps1 test
```

Expected output:
```
[OK] Public API responsive via Cloudflare (Status: 200)
  Response: {"status":"healthy",...}
  [OK] Cloudflare headers detected (CF-RAY: ...)
```

## Quick Start (Once Fixed)

```powershell
# Start everything
.\launch-simple.ps1
# Choose option 1

# Test after 15 seconds
.\tunnel-debug.ps1 test

# Access
# Local:  http://localhost:8000/docs
# Public: https://qwen.codeblazar.org/docs
```

## Current Status Summary

| Component | Status | Details |
|-----------|--------|---------|
| API Server | ✓ Working | Port 8000, PID: 16952 |
| Cloudflared Process | ✓ Running | PID: 26864 |
| Tunnel Connection | ✓ Connected | 4 edge servers |
| Local Access | ✓ Working | http://localhost:8000/docs |
| Public DNS | ✓ Resolving | Cloudflare IPs |
| **Public Routing** | **✗ Not Configured** | **Needs dashboard setup** |

## Notes

- The tunnel needs to stay running (don't close the PowerShell window)
- API needs to be running BEFORE tunnel connects
- Allow 10-15 seconds after starting for full connection
- Cloudflared version is outdated (2025.8.1) - consider updating to 2025.10.1

## Update Cloudflared

```powershell
winget upgrade --id Cloudflare.cloudflared
```

## Files Created

- `launch-simple.ps1` - Main launcher (no Unicode issues)
- `tunnel-debug.ps1` - Diagnostic tool
- `TUNNEL_GUIDE.md` - Complete documentation
- `STATUS.md` - This file
