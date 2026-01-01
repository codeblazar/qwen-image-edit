# Admin Guide - Qwen Image Edit (Home PC)

This project is hosted on a home PC and may be offline when you’re not actively using it.
This guide is the **bring-up checklist** for making `https://qwen.codeblazar.org` work for clients (FlutterFlow, Swagger, scripts).

---

## 1) What Must Be Running

For public access via `https://qwen.codeblazar.org/...`, the home PC must be running **both**:

1. **Qwen API server** (FastAPI) listening on `localhost:8000`
2. **Cloudflare Tunnel connector** (`cloudflared`) connected and routing `qwen.codeblazar.org` → `localhost:8000`

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
- Tunnel credentials/config missing or not authenticated
- Tunnel exists in Cloudflare but has **no active connectors** (home PC offline)

---

## 5) Troubleshooting (Fast)

### Check tunnel status

```powershell
.\tunnel-debug.ps1 status
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

This repo’s “production” path is **not Docker-based** by default.
The public hostname is served via **Cloudflare Tunnel + a local Python FastAPI server**.
If you later wrap it in Docker, you must still ensure the equivalent of:
- API is reachable on the port the tunnel points to
- cloudflared runs and is connected
