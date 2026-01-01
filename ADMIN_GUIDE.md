# Admin Guide - Qwen Image Edit (Home PC)

This project is hosted on a home PC and may be offline when you’re not actively using it.
This guide is the **bring-up checklist** for making `https://qwen.codeblazar.org` work for clients (FlutterFlow, Swagger, scripts).

---

## 1) What Must Be Running

For public access via `https://qwen.codeblazar.org/...`, the home PC must be running **both**:

1. **Qwen API server** (FastAPI) listening on `localhost:8000`
2. **Cloudflare Tunnel connector** (recommended: Docker `cloudflare/cloudflared`) connected and routing `qwen.codeblazar.org` → the API

If either is down, clients will fail.

---

## 2) Start Services (Recommended)

On the home PC:

```powershell
.\launch.ps1
# Choose option 1: API Server + Cloudflare Tunnel
```

Alternative (runs as PowerShell background jobs; services stop if you close that window):

```powershell
.\launch-background.ps1
# Choose option 1
```

---

## 3) Verify It’s Online

These two URLs are the quickest verification:

- Swagger UI: `https://qwen.codeblazar.org/docs`
- Health check: `https://qwen.codeblazar.org/api/v1/health`

Local verification (on the home PC) if you’re debugging:

- Local health: `http://localhost:8000/api/v1/health`
- Local Swagger: `http://localhost:8000/docs`

---

## 4) Cloudflare Error 1033 (What It Means)

If you see **Cloudflare Error 1033** in the browser:

- Cloudflare cannot find an **active tunnel connection** for the hostname.
- This is almost always a **home PC / tunnel connector** issue (not a FlutterFlow client issue).

Typical causes:
- `cloudflared` is not running
- Tunnel token/credentials missing or not authenticated
- Tunnel exists in Cloudflare but has **no active connectors** (home PC offline)

---

## 5) Troubleshooting (Fast)

### Check tunnel status

```powershell
.\tunnel-debug.ps1 status
```

### Token-based tunnel (Docker) setup

If you created a new tunnel in Cloudflare and got a **token**, provide it locally (do not commit it):

Option A (recommended): create `cloudflare-tunnel-token.local.txt` (gitignored)
- Put the token string as the only contents of that file
- Template file: `cloudflare-tunnel-token.local.txt.example`

Option B: set an environment variable before launching
```powershell
$env:QWEN_CF_TUNNEL_TOKEN = "<paste token>"
```

### Test local + public connectivity

```powershell
.\tunnel-debug.ps1 test
```

### Restart tunnel

```powershell
.\tunnel-debug.ps1 restart
```

### If cloudflared is missing

```powershell
winget install --id Cloudflare.cloudflared
```

### If the tunnel config is missing

The tunnel uses a Cloudflare config file typically at:
- `%USERPROFILE%\.cloudflared\config.yml`

If it’s missing, the tunnel must be reconfigured/authenticated in Cloudflare Zero Trust.

---

## 6) API Key (Admin)

The API uses `X-API-Key`.
On the home PC, the current key is stored at:
- `api/.api_key`

Scripts:

```powershell
# Show current key
.\api\show-api-key.ps1

# Rotate key
.\api\manage-key.ps1 -Rotate
```

---

## 7) Notes (Docker)

Recommended setup:
- Run the API on the Windows host (Python/venv)
- Run the Cloudflare connector in Docker (token-based)

In Cloudflare’s public hostname configuration, the origin should be:
- `http://localhost:8000` if `cloudflared` runs natively on Windows
- `http://host.docker.internal:8000` if `cloudflared` runs inside Docker (Windows)
