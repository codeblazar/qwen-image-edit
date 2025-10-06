# Quick Start: Job Queue API

## Load Model (Once at Startup)

```bash
curl -X POST "http://10.10.0.17:8000/api/v1/load-model?model=qwen-4step" \
  -H "X-API-Key: your-api-key"
```

Models: `qwen-4step` (fast), `qwen-8step` (balanced), `qwen-40step` (quality)

---

## Submit Job

```bash
curl -X POST "http://10.10.0.17:8000/api/v1/submit" \
  -H "X-API-Key: your-api-key" \
  -F "image=@input.jpg" \
  -F "instruction=Make the sky blue" \
  -F "seed=42"
```

**Response:**
```json
{
  "job_id": "abc123...",
  "status": "queued",
  "position": 3,
  "estimated_wait_seconds": 60
}
```

---

## Check Status

```bash
curl -X GET "http://10.10.0.17:8000/api/v1/status/abc123..." \
  -H "X-API-Key: your-api-key"
```

**Response (Completed):**
```json
{
  "job_id": "abc123...",
  "status": "completed",
  "result_path": "qwen-4step_20240115_103125_s42_a1b2c3d4.png",
  "result_seed": 42
}
```

---

## Check Queue

```bash
curl -X GET "http://10.10.0.17:8000/api/v1/queue" \
  -H "X-API-Key: your-api-key"
```

**Response:**
```json
{
  "queue_size": 4,
  "max_queue_size": 10,
  "queued_count": 3,
  "processing_count": 1
}
```

---

## Python Example

```python
import requests
import time

API = "http://10.10.0.17:8000/api/v1"
KEY = {"X-API-Key": "your-api-key"}

# Submit
with open("input.jpg", "rb") as f:
    r = requests.post(f"{API}/submit", headers=KEY, 
                      files={"image": f},
                      data={"instruction": "Make sky blue", "seed": 42})

job_id = r.json()["job_id"]
print(f"Job: {job_id}")

# Poll
while True:
    s = requests.get(f"{API}/status/{job_id}", headers=KEY).json()
    if s["status"] == "completed":
        print(f"✅ {s['result_path']}")
        break
    print(f"⏳ {s['status']}...")
    time.sleep(5)
```

---

## Error Codes

- **200**: Success
- **400**: Invalid input (too large, wrong format, etc.)
- **401**: Invalid API key
- **404**: Job not found (cleaned up after 1 hour)
- **429**: Queue full (max 10 jobs)
- **500**: Server error

---

## Tips

✅ Poll every 5-10 seconds (not faster)
✅ Check queue status before batch submissions
✅ Handle 429 errors (wait and retry)
✅ Jobs auto-delete after 1 hour
✅ Max 10 jobs in queue
✅ Processing is FIFO (first in, first out)

---

See `QUEUE_SYSTEM.md` for full documentation.
