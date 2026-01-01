# Qwen Image Edit - Cloudflare Tunnel Guide

## Quick Start

### Option 1: Everything Together (Recommended)
```powershell
.\launch.ps1
# Choose option 1 (API Server + Cloudflare Tunnel)
```

This will start both the API server and the Cloudflare tunnel automatically.

### Option 2: Manual Control
```powershell
# Start API first
.\launch.ps1  # Choose option 2 (API Server Only)

# Then start tunnel separately
.\tunnel-debug.ps1 start
```

## Troubleshooting

### Check Status
```powershell
.\tunnel-debug.ps1 status
```

This shows:
- ✅ Cloudflared installation
- ✅ Tunnel configuration
- ✅ Running processes
- ✅ Connection status

### Test Connectivity
```powershell
.\tunnel-debug.ps1 test
```

Tests both:
- Local: `http://localhost:8000/api/v1/health`
- Public: `https://qwen.codeblazar.org/api/v1/health`

### Cloudflare Error 1033

If you see **Error 1033** from Cloudflare when visiting the public URL, Cloudflare is telling you it **cannot reach an active tunnel connection**.

Common causes:
- `cloudflared` is not running on the server
- The tunnel is running but not authenticated / credentials missing
- The tunnel exists in Cloudflare, but has **no active connectors**

Quick fixes:
```powershell
# Start both API + tunnel
.\launch.ps1  # choose option 1

# Or verify tunnel connectivity
.\tunnel-debug.ps1 status
.\tunnel-debug.ps1 restart
```

### Cloudflare Error 502 (Bad Gateway)

If the public URL returns **502 Bad Gateway** while the local API is healthy, Cloudflare is reaching the tunnel, but **cloudflared cannot reach the origin service**.

First, confirm the local API works:
```powershell
curl http://localhost:8000/api/v1/health
```

Then check tunnel logs for the configured origin URL:
```powershell
docker logs qwen-cloudflared --tail 200
```

If logs show a bad origin such as `http://jhost.docker.internal:8000` (typo) or `http://localhost:8000` (wrong from inside Docker), fix the Public Hostname service in Cloudflare Zero Trust to:
- `http://host.docker.internal:8000`

Once Cloudflare is pointing at `http://host.docker.internal:8000`, restart the tunnel and re-test.

### Common Issues

#### 1. Tunnel Running But Not Connected
**Symptoms:**
- Cloudflared process exists
- "does not have any active connection" message
- Public URL doesn't work

**Cause:** API server not running on port 8000

**Fix:**
```powershell
.\launch.ps1  # Option 1 or 2 to start API
```

#### 2. Both Running But Public URL Still 404
**Symptoms:**
- API responds on localhost
- Tunnel shows as running
- Public URL returns 404

**Possible Causes:**
1. Tunnel needs 10-15 seconds to establish connection
2. DNS propagation delay
3. Cloudflare dashboard configuration issue

**Fix:**
```powershell
# Wait a bit, then test again
Start-Sleep -Seconds 15
.\tunnel-debug.ps1 test

# If still failing, restart tunnel
.\tunnel-debug.ps1 restart
```

#### 3. Cloudflared Not Found
**Symptoms:**
- "[X] cloudflared NOT FOUND"

**Fix:**
```powershell
winget install --id Cloudflare.cloudflared
```

#### 3b. Docker Tunnel Token Missing
**Symptoms:**
- Launch scripts or `tunnel-debug.ps1` report tunnel token not configured

**Fix:**
- Create `cloudflare-tunnel-token.local.txt` (see `cloudflare-tunnel-token.local.txt.example`), OR
- Set env var `QWEN_CF_TUNNEL_TOKEN` before launching

#### 4. Tunnel Configuration Missing
**Symptoms:**
- Config file not found at `C:\Users\<username>\.cloudflared\config.yml`

**Fix:** The tunnel needs to be reconfigured. Contact the system administrator or see: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/

### Stopping Services

```powershell
# Stop everything
.\launch.ps1  # Option S

# Or stop tunnel only
.\tunnel-debug.ps1 stop
```

## Architecture

```
┌─────────────────┐
│   Internet      │
└────────┬────────┘
         │
         │ HTTPS
         ▼
┌─────────────────────────┐
│  qwen.codeblazar.org    │  (DNS → Cloudflare)
└────────┬────────────────┘
         │
         │ Cloudflare Tunnel
         ▼
┌─────────────────────────┐
│  cloudflared.exe        │  (Local process)
│  PID: varies            │
└────────┬────────────────┘
         │
         │ HTTP (localhost:8000)
         ▼
┌─────────────────────────┐
│  Qwen API Server        │  (FastAPI/Python)
│  Port: 8000             │
└─────────────────────────┘
```

## Monitoring

### View Live Tunnel Logs
When you start the tunnel with `.\tunnel-debug.ps1 start`, a new PowerShell window opens with debug logging. Watch this window for:
- Connection establishment
- HTTP requests
- Errors and warnings

### Check Tunnel in Cloudflare Dashboard
1. Log in to Cloudflare Zero Trust dashboard
2. Navigate to Networks > Tunnels
3. Find "qwen" tunnel
4. Check connection status and traffic

## URLs

- **Local Swagger UI:** http://localhost:8000/docs
- **Public Swagger UI:** https://qwen.codeblazar.org/docs
- **Local Health:** http://localhost:8000/api/v1/health  
- **Public Health:** https://qwen.codeblazar.org/api/v1/health

## Files

- `launch.ps1` - Main launcher with tunnel integration
- `tunnel-debug.ps1` - Tunnel diagnostics and management
- `~\.cloudflared\config.yml` - Tunnel configuration
- `~\.cloudflared\<tunnel-id>.json` - Tunnel credentials

## Advanced

### Update Cloudflared
```powershell
winget upgrade --id Cloudflare.cloudflared
```

### Manual Tunnel Start (Debug Mode)
```powershell
cloudflared tunnel --loglevel debug run qwen
```

### Manual Tunnel Start (Docker, Token-Based)

If you created a new tunnel in Cloudflare and got a token, run:
```powershell
docker run --rm cloudflare/cloudflared:latest tunnel --no-autoupdate run --token <YOUR_TOKEN>
```

If the API is running on the Windows host and cloudflared runs in Docker, your Cloudflare public hostname origin should be:
- `http://host.docker.internal:8000`

### Check Tunnel Connections
```powershell
cloudflared tunnel info qwen
```

### List All Tunnels
```powershell
cloudflared tunnel list
```
