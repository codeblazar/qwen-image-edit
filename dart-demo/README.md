# Dart Demo (Handoff Package for FlutterFlow)

This folder is meant to be zipped and sent to a colleague who will build a FlutterFlow app.
They do **not** need access to the host machine.

What this demo provides:
- A working Dart CLI that calls the API (`bin/qwen_api_demo.dart`)
- A tiny reusable Dart client (`lib/qwen_image_edit_client.dart`) that shows the exact HTTP request shape FlutterFlow must replicate

## The Workflow (Host vs Client)

### What you need from Pete (the host)
This API runs on Pete’s PC. If it’s not running, you can’t connect.

1. Contact Pete and ask him to start the API + internet tunnel.
  - He should run `launch.ps1` and choose **Option 1: API + Cloudflare tunnel**.
2. Ask Pete to give you:
  - **API base URL**: `https://qwen.codeblazar.org/api/v1`
  - **API key** (a long string)
3. If you see connection errors (timeout / refused), call Pete again — the API is probably off.

Quick sanity check (optional):
- Public health: `https://qwen.codeblazar.org/api/v1/health`
- Public docs: `https://qwen.codeblazar.org/docs`

### Your steps (client)
1. Install Dart SDK (or Flutter, which includes Dart).
2. Run the Dart CLI in this folder to validate connectivity and request formatting.
3. Use the request details below to create the FlutterFlow API Call / Custom Action.

## Prereqs (Client)

- Dart SDK installed (`dart --version`) OR Flutter installed (`flutter --version`)
- Network access to the host’s API base URL (host must be running the API)
- API key provided by the host

## Setup (Client)

From the folder root:

```powershell
cd dart-demo
dart pub get
```

## Run the CLI (Client)

You must provide:
- `--api-base` (host will tell you)
- `--api-key` (host will tell you) OR set `QWEN_API_KEY`
- `--image` path to a real `.png` / `.jpg` on your machine
- `--instruction` text

Example:

```powershell
cd dart-demo

# Option A: pass key directly
dart run bin\qwen_api_demo.dart ^
  --api-base https://qwen.codeblazar.org/api/v1 ^
  --api-key YOUR_API_KEY_HERE ^
  --image "C:\\path\\to\\seed.png" ^
  --instruction "Add sunglasses" ^
  --out ".\\edited.png"

# Option B: use env var
$env:QWEN_API_KEY = "YOUR_API_KEY_HERE"
dart run bin\qwen_api_demo.dart --api-base https://qwen.codeblazar.org/api/v1 --image "C:\\path\\to\\seed.png" --instruction "Add sunglasses" --out .\\edited.png
```

If you see connection errors (timeout / refused), call the host to turn the API on.

## FlutterFlow Mapping (What to Build)

Your FlutterFlow call should match this:

- Method: `POST`
- URL: `{API_BASE}/submit` (example: `https://qwen.codeblazar.org/api/v1/submit`)
- Headers:
  - `X-API-Key: <api key>`
- Body type: `multipart/form-data`
- Form fields:
  - `instruction` (string, required)
  - `system_prompt` (string, optional)
  - `preset` (string, optional: `4-step|8-step|40-step`)
  - `seed` (string/int, optional)
- File field:
  - `image` (file, required) — PNG/JPG

Response:
- On success (queued): JSON like `{ "job_id": "...", "status": "queued", ... }`
- If the queue is full: HTTP **429** with JSON `{ "detail": "Queue full" }`
- On validation/prompt rejection: HTTP **400** with JSON `{ "detail": "..." }`

Then you must poll for completion:

1) `GET {API_BASE}/status/{job_id}`
  - Headers: `X-API-Key: <api key>`
  - Response JSON includes `status`:
    - `queued` / `processing` / `completed` / `failed`

2) When status becomes `completed`, download the image:
  - `GET {API_BASE}/status/{job_id}/result`
  - Headers: `X-API-Key: <api key>`
  - Response: raw PNG bytes

Note:
- `/edit` exists but is intended for **admin/testing only** (synchronous, not queued).

Queue timing expectation:
- The queue can hold up to ~10 jobs. If each job takes ~20 seconds, worst-case wait can be around 200 seconds before your job finishes. This is normal.

## HTTP 400 (What it means / common causes)

If you get **HTTP 400**, the request was rejected due to input validation or prompt policy. Common examples:

- **Blocked prompt terms**: your `instruction` (or `system_prompt`) contains disallowed terms (example: “turn this into a nude”).
- **Instruction too long**: instruction exceeds the server limit (currently 500 chars).
- **Invalid image type**: the uploaded file isn’t a PNG/JPG, or it’s not a valid image.
- **Image too large**: file size over ~10MB.
- **Image dimensions too large**: width/height over 2048 px.
- **No model loaded**: the host started the server but it hasn’t finished loading a model yet.

What to do:
- Read the JSON `detail` message and fix the input.
- If the error suggests the server isn’t ready (model not loaded) or you can’t connect at all, call Pete.

## Notes

- The API performs **image editing** (image-in + instruction) — it is not a text-to-image endpoint.
- Prompts may be rejected (HTTP 400) if they contain blocked terms; the error message will be in the JSON `detail`.

## CLI Flags

- `--api-base` (default: `http://localhost:8000/api/v1`)
- `--api-key` (or env `QWEN_API_KEY`)
- `--image` (required)
- `--instruction` (required)
- `--system-prompt` (optional)
- `--preset` (optional: `4-step`, `8-step`, `40-step`)
- `--seed` (optional int)
- `--out` (default: `edited.png`)
- `--poll-seconds` (default: `5`)
- `--timeout-minutes` (default: `15`)

