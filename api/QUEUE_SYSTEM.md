# Job Queue System

The Qwen Image Edit API now includes a robust job queue system designed for handling concurrent requests from multiple stations.

## Overview

When multiple users or systems ("stations") need to submit image editing requests simultaneously, the job queue system:

- **Queues incoming requests** (max 10 jobs)
- **Processes jobs sequentially** in FIFO order
- **Returns 429 (Too Many Requests)** if queue is full
- **Tracks job status** through the entire lifecycle
- **Auto-cleans completed jobs** after 1 hour

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Station 1  │────▶│             │     │             │
├─────────────┤     │             │     │   Pipeline  │
│  Station 2  │────▶│  Job Queue  │────▶│   Manager   │
├─────────────┤     │  (Max 10)   │     │   (GPU)     │
│  Station 3  │────▶│             │     │             │
└─────────────┘     └─────────────┘     └─────────────┘
                           │
                           ▼
                    ┌─────────────┐
                    │   Results   │
                    │  (1 hr TTL) │
                    └─────────────┘
```

## Endpoints

### 1. Submit Job (Recommended for Multiple Stations)

**POST** `/api/v1/submit`

Submit an image editing job to the queue. Non-blocking - returns immediately with a job ID.

**Request:**
```bash
curl -X POST "http://10.10.0.17:8000/api/v1/submit" \
  -H "X-API-Key: your-api-key" \
  -F "image=@input.jpg" \
  -F "instruction=Make the sky blue and add clouds" \
  -F "seed=42"
```

**Response (200 OK):**
```json
{
  "job_id": "3317c7b1-4a5d-4e8f-9c2a-1b3d4e5f6a7b",
  "status": "queued",
  "position": 3,
  "message": "Job queued successfully. Position: 3",
  "estimated_wait_seconds": 60
}
```

**Response (429 Too Many Requests):**
```json
{
  "detail": "Queue is full (maximum 10 jobs). Please try again later."
}
```

**Parameters:**
- `image` (file, required): Input image (JPG/PNG, max 10MB, max 2048x2048px)
- `instruction` (string, required): Editing instruction (max 500 chars)
- `seed` (int, optional): Random seed for reproducibility
- `system_prompt` (string, optional): Custom system prompt

---

### 2. Check Job Status

**GET** `/api/v1/status/{job_id}`

Check the status of a submitted job. Poll this endpoint to monitor progress.

**Request:**
```bash
curl -X GET "http://10.10.0.17:8000/api/v1/status/3317c7b1-4a5d-4e8f-9c2a-1b3d4e5f6a7b" \
  -H "X-API-Key: your-api-key"
```

**Response (Queued):**
```json
{
  "job_id": "3317c7b1-4a5d-4e8f-9c2a-1b3d4e5f6a7b",
  "status": "queued",
  "position": 2,
  "created_at": "2024-01-15T10:30:00",
  "started_at": null,
  "completed_at": null,
  "result_path": null,
  "result_seed": null,
  "error": null,
  "instruction": "Make the sky blue and add clouds",
  "model": "qwen-4step"
}
```

**Response (Processing):**
```json
{
  "job_id": "3317c7b1-4a5d-4e8f-9c2a-1b3d4e5f6a7b",
  "status": "processing",
  "position": null,
  "created_at": "2024-01-15T10:30:00",
  "started_at": "2024-01-15T10:31:00",
  "completed_at": null,
  "result_path": null,
  "result_seed": null,
  "error": null,
  "instruction": "Make the sky blue and add clouds",
  "model": "qwen-4step"
}
```

**Response (Completed):**
```json
{
  "job_id": "3317c7b1-4a5d-4e8f-9c2a-1b3d4e5f6a7b",
  "status": "completed",
  "position": null,
  "created_at": "2024-01-15T10:30:00",
  "started_at": "2024-01-15T10:31:00",
  "completed_at": "2024-01-15T10:31:25",
  "result_path": "qwen-4step_20240115_103125_s42_a1b2c3d4.png",
  "result_seed": 42,
  "error": null,
  "instruction": "Make the sky blue and add clouds",
  "model": "qwen-4step"
}
```

**Response (Failed):**
```json
{
  "job_id": "3317c7b1-4a5d-4e8f-9c2a-1b3d4e5f6a7b",
  "status": "failed",
  "position": null,
  "created_at": "2024-01-15T10:30:00",
  "started_at": "2024-01-15T10:31:00",
  "completed_at": "2024-01-15T10:31:15",
  "result_path": null,
  "result_seed": null,
  "error": "CUDA out of memory",
  "instruction": "Make the sky blue and add clouds",
  "model": "qwen-4step"
}
```

**Response (404 Not Found):**
```json
{
  "detail": "Job 3317c7b1-4a5d-4e8f-9c2a-1b3d4e5f6a7b not found. It may have been cleaned up (jobs are kept for 1 hour after completion)."
}
```

**Job States:**
- `queued`: Waiting in queue (check `position` field)
- `processing`: Currently being generated
- `completed`: Done! Check `result_path` and `result_seed`
- `failed`: Error occurred (check `error` field)

---

### 3. Queue Status

**GET** `/api/v1/queue`

Get overall queue statistics. Useful for monitoring system load.

**Request:**
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
  "processing_count": 1,
  "completed_count": 15,
  "failed_count": 2,
  "current_job_id": "3317c7b1-4a5d-4e8f-9c2a-1b3d4e5f6a7b",
  "total_jobs": 20
}
```

**Fields:**
- `queue_size`: Current number of jobs in queue (waiting to be processed)
- `max_queue_size`: Maximum queue capacity (10)
- `queued_count`: Total jobs with status "queued"
- `processing_count`: Total jobs currently being processed (usually 1)
- `completed_count`: Total completed jobs (including those cleaned up)
- `failed_count`: Total failed jobs
- `current_job_id`: ID of the job currently being processed (null if idle)
- `total_jobs`: Total tracked jobs (may be less than sum due to cleanup)

---

## Workflow Examples

### Example 1: Submit and Poll

```python
import requests
import time

API_URL = "http://10.10.0.17:8000/api/v1"
API_KEY = "your-api-key"
HEADERS = {"X-API-Key": API_KEY}

# 1. Submit job
with open("input.jpg", "rb") as f:
    response = requests.post(
        f"{API_URL}/submit",
        headers=HEADERS,
        files={"image": f},
        data={
            "instruction": "Make the sky blue",
            "seed": 42
        }
    )

if response.status_code == 429:
    print("Queue is full, try again later")
    exit(1)

job = response.json()
job_id = job["job_id"]
print(f"Job submitted: {job_id}, position {job['position']}")

# 2. Poll for completion
while True:
    response = requests.get(f"{API_URL}/status/{job_id}", headers=HEADERS)
    status = response.json()
    
    if status["status"] == "completed":
        print(f"✅ Completed! Result: {status['result_path']}")
        print(f"   Seed used: {status['result_seed']}")
        break
    elif status["status"] == "failed":
        print(f"❌ Failed: {status['error']}")
        break
    elif status["status"] == "processing":
        print(f"⏳ Processing...")
    else:  # queued
        print(f"⏳ Queued (position {status['position']})")
    
    time.sleep(5)  # Poll every 5 seconds
```

### Example 2: Batch Submission with Queue Check

```python
import requests
import time

API_URL = "http://10.10.0.17:8000/api/v1"
API_KEY = "your-api-key"
HEADERS = {"X-API-Key": API_KEY}

images = [
    ("image1.jpg", "Add a sunset"),
    ("image2.jpg", "Make it winter"),
    ("image3.jpg", "Add rain"),
]

job_ids = []

for image_path, instruction in images:
    # Check queue status first
    queue_status = requests.get(f"{API_URL}/queue", headers=HEADERS).json()
    
    if queue_status["queue_size"] >= 8:  # Leave some buffer
        print(f"⚠️  Queue almost full ({queue_status['queue_size']}/10), waiting...")
        time.sleep(10)
        continue
    
    # Submit job
    with open(image_path, "rb") as f:
        response = requests.post(
            f"{API_URL}/submit",
            headers=HEADERS,
            files={"image": f},
            data={"instruction": instruction}
        )
    
    if response.status_code == 429:
        print(f"Queue full, skipping {image_path}")
        continue
    
    job = response.json()
    job_ids.append((image_path, job["job_id"]))
    print(f"✅ Submitted {image_path}: {job['job_id']}")

print(f"\n📊 Submitted {len(job_ids)} jobs")

# Monitor all jobs
while job_ids:
    for image_path, job_id in job_ids[:]:
        response = requests.get(f"{API_URL}/status/{job_id}", headers=HEADERS)
        status = response.json()
        
        if status["status"] == "completed":
            print(f"✅ {image_path} → {status['result_path']}")
            job_ids.remove((image_path, job_id))
        elif status["status"] == "failed":
            print(f"❌ {image_path} failed: {status['error']}")
            job_ids.remove((image_path, job_id))
    
    if job_ids:
        print(f"⏳ {len(job_ids)} jobs remaining...")
        time.sleep(10)
```

---

## Queue Behavior

### Queue Capacity
- **Maximum**: 10 jobs
- **When full**: Returns HTTP 429 (Too Many Requests)
- **Recommendation**: Check `/api/v1/queue` before submitting large batches

### Processing Order
- **FIFO** (First In, First Out)
- Jobs are processed in the order they were submitted
- The `position` field shows where you are in the queue

### Job Cleanup
- **Retention**: 1 hour after completion/failure
- Completed jobs are automatically removed after 1 hour
- Jobs older than 1 hour will return 404

### Polling Recommendations
- **While queued/processing**: Poll every 5-10 seconds
- **After completion**: Stop polling
- **Typical processing times**:
  - qwen-4step: ~20 seconds
  - qwen-8step: ~40 seconds
  - qwen-40step: ~3 minutes

---

## Comparison: Queue vs Direct Edit

| Feature | `/api/v1/submit` (Queue) | `/api/v1/edit` (Direct) |
|---------|-------------------------|------------------------|
| **Blocking** | ❌ Non-blocking | ✅ Blocking |
| **Multiple stations** | ✅ Yes (recommended) | ⚠️ Race conditions |
| **Rate limiting** | ✅ Built-in (max 10) | ❌ None |
| **Status tracking** | ✅ Yes | ❌ No |
| **Timeout handling** | ✅ Graceful | ⚠️ May timeout |
| **Use case** | Production, multi-user | Single user, testing |

**Recommendation:** Use `/api/v1/submit` for production environments with multiple stations. Use `/api/v1/edit` only for single-user scenarios or testing.

---

## Error Handling

### Queue Full (429)
```json
{
  "detail": "Queue is full (maximum 10 jobs). Please try again later."
}
```
**Solution:** Wait and retry, or check `/api/v1/queue` to monitor capacity

### Job Not Found (404)
```json
{
  "detail": "Job abc123 not found. It may have been cleaned up (jobs are kept for 1 hour after completion)."
}
```
**Solution:** Job completed over 1 hour ago and was cleaned up

### Invalid Input (400)
```json
{
  "detail": "Image too large (15.2MB). Maximum 10MB allowed."
}
```
**Solution:** Resize image or use different file

### No Model Loaded (400)
```json
{
  "detail": "No model loaded. Please call /api/v1/load-model first to load a model."
}
```
**Solution:** Call `/api/v1/load-model` before submitting jobs

---

## Testing

Run the queue system tests:

```powershell
cd C:\Projects\qwen-image-edit\api
..\venv\Scripts\python.exe test_queue.py
```

**Tests include:**
- ✅ Basic job submission and completion
- ✅ Queue full scenario (429 response)
- ✅ Concurrent job submissions (5 jobs)
- ✅ Queue status tracking
- ✅ Job retrieval by ID

---

## Configuration

Queue settings are in `api/job_queue.py`:

```python
# Maximum queue size (default: 10)
job_queue = JobQueue(max_size=10)

# Cleanup age in seconds (default: 3600 = 1 hour)
job_queue = JobQueue(cleanup_age_seconds=3600)
```

To adjust:
1. Edit `api/main.py`
2. Find `job_queue = JobQueue()`
3. Set `max_size` and `cleanup_age_seconds` as needed
4. Restart the API

---

## Monitoring

### Check Queue Health
```bash
# Get current queue status
curl -H "X-API-Key: your-key" http://10.10.0.17:8000/api/v1/queue

# Check system health
curl -H "X-API-Key: your-key" http://10.10.0.17:8000/api/v1/health
```

### Logs
The queue system logs to console:
```
[JobQueue] Started - Max size: 10, Cleanup age: 3600s
[JobQueue] Job 3317c7b1 submitted - Queue size: 1
[JobQueue] Worker started
[JobQueue] Processing job 3317c7b1 - Make the sky blue...
[JobQueue] Job 3317c7b1 completed - Path: qwen-4step_20240115_103125_s42_a1b2c3d4.png
```

---

## Best Practices

1. **Check queue status** before batch submissions:
   ```python
   queue = requests.get(f"{API_URL}/queue").json()
   if queue["queue_size"] < 8:  # Leave buffer
       # Submit job
   ```

2. **Poll responsibly**:
   - Poll every 5-10 seconds (not faster)
   - Stop polling when status is `completed` or `failed`

3. **Handle 429 errors gracefully**:
   ```python
   if response.status_code == 429:
       time.sleep(30)  # Wait 30 seconds
       # Retry
   ```

4. **Store job IDs persistently**:
   - Save job_id to database/file
   - Can retrieve status later (within 1 hour)

5. **Load model once** at startup:
   ```bash
   curl -X POST -H "X-API-Key: your-key" \
     "http://10.10.0.17:8000/api/v1/load-model?model=qwen-4step"
   ```

---

## See Also

- [API README](README.md) - General API documentation
- [HARDENING.md](HARDENING.md) - Robustness improvements
- [AUDIT_REPORT.md](AUDIT_REPORT.md) - Code quality audit
