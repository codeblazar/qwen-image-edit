# FlutterFlow Integration Guide - Qwen Image Edit API

This guide shows you how to integrate the Qwen Image Edit API into your FlutterFlow app using the queue-based workflow for reliable, production-ready image editing.

---

## Quick Overview

This API uses a **queue-based workflow**:

1. **Submit job** → Get job_id and position in queue
2. **Poll for status** → Check if job is complete
3. **Retrieve result** → Get the edited image

This approach prevents timeouts and handles concurrent users effectively.

---

## Prerequisites

### What You Need

1. **API Key** - Get this from your API administrator (Pete)
2. **API Base URL** - `https://qwen.codeblazar.org/api/v1`
3. **Model loaded** - The API needs a model loaded (done once by admin)

**Important:** Store your API key in a configuration file or environment variable rather than hardcoding it. This makes key rotation easier when needed.

### Test the API First

Open your browser and navigate to:
```
https://qwen.codeblazar.org/docs
```

You should see the Swagger UI documentation. If not, contact your API administrator.

---

## FlutterFlow Setup

### 1. Create API Group

In FlutterFlow:

1. Go to **API Calls** (lightning bolt icon in left sidebar)
2. Click **+ Add** → **API Group**
3. Configure:
   - **Group Name:** `QwenImageAPI`
   - **Base URL:** `https://qwen.codeblazar.org/api/v1`
   - **Add Header:**
     - **Key:** `X-API-Key`
     - **Value:** Reference your config variable (e.g., `Config.apiKey`) or use App State

**Note:** All API calls in this group will automatically include the API key header. Consider storing the API key in App State or a config file for easy updates.

---

## Testing with Swagger UI

Before building your FlutterFlow integration, test the API endpoints using the Swagger UI to understand the request/response formats.

### Test Submit Job Endpoint

1. Navigate to `https://qwen.codeblazar.org/docs`
2. Locate the **POST /api/v1/submit** endpoint
3. Click to expand it
4. Click **"Try it out"** button
5. Click **"Add string item"** under X-API-Key
6. Enter your API key value
7. For the request body:
   - **image:** Click "Choose File" and select a JPG or PNG (max 10MB, max 2048x2048px)
   - **instruction:** Enter text like "Make the sky blue"
   - **seed:** (Optional) Enter a number like `42`
  - **preset:** (Optional) Preferred field name. Select `4-step`, `8-step`, or `40-step`.
    - Important: The API uses the **currently loaded preset**. If you send `preset`, it must match the loaded preset or you’ll get `409 Conflict`.
    - For most FlutterFlow clients, you should **omit `preset`** and just use whatever preset the server admin has loaded by default.
  - **model:** (Optional) Deprecated alias for `preset` (avoid in new integrations)
8. Click **"Execute"**

**Expected Response (200):**
```json
{
  "job_id": "abc123-def456-789...",
  "status": "queued",
  "position": 1,
  "message": "Job queued successfully. Position: 1",
  "estimated_wait_seconds": 0
}
```

Copy the `job_id` value - you'll need it for the next test.

### Test Status Check Endpoint

1. In Swagger UI, locate **GET /api/v1/status/{job_id}**
2. Click to expand it
3. Click **"Try it out"**
4. In the X-API-Key field, enter your API key
5. In the **job_id** parameter field, paste the job_id from the previous step
6. Click **"Execute"**

**Expected Response (Queued):**
```json
{
  "job_id": "abc123-def456-789...",
  "status": "queued",
  "position": 1,
  "created_at": "2024-10-06T10:30:00",
  ...
}
```

Wait 5-10 seconds, then click "Execute" again to poll.

**Expected Response (Completed):**
```json
{
  "job_id": "abc123-def456-789...",
  "status": "completed",
  "result_path": "qwen-4step_20241006_103125_s42_abc123.png",
  "result_seed": 42,
  ...
}
```

### Test Queue Status Endpoint

1. In Swagger UI, locate **GET /api/v1/queue**
2. Click to expand it
3. Click **"Try it out"**
4. Enter your API key in the X-API-Key field
5. Click **"Execute"**

**Expected Response:**
```json
{
  "queue_size": 1,
  "max_queue_size": 10,
  "queued_count": 0,
  "processing_count": 1,
  "completed_count": 5,
  "failed_count": 0
}
```

This shows current queue load and processing status.

---

## Queue-Based Workflow Implementation

This is the production-ready approach for FlutterFlow integration.

### Step 1: Submit the Job

**Create API Call: "Submit Image Job"**

- **Method:** `POST`
- **Endpoint:** `/submit`
- **Body Type:** `Multipart Form Data`
- **Add Fields:**
  - `image` (type: File) - Your image file
  - `instruction` (type: Text) - e.g., "Make the sky blue"
  - `seed` (type: Number, optional) - e.g., `42`
  - `preset` (type: Text, optional) - Preferred field name. One of: `"4-step"`, `"8-step"`, `"40-step"`.
    - Most apps should **omit this** and use the server’s default preset.
    - If you include it, it must match the currently loaded preset or you’ll get `409 Conflict`.
  - `model` (type: Text, optional) - Deprecated alias for `preset` (avoid)

**Model Selection Guide:**
- **4-step** (default): Ultra-fast (~20 seconds) - Good for testing and quick edits
- **8-step**: Balanced quality (~40 seconds) - Good for production use
- **40-step**: Highest quality (~3 minutes) - Best results, slower processing

**Response Structure:**
```json
{
  "job_id": "abc123-def456-...",
  "status": "queued",
  "position": 3,
  "message": "Job queued successfully",
  "estimated_wait_seconds": 60
}
```

**FlutterFlow Action Flow:**
1. User selects image
2. User enters instruction text
3. (Optional) User selects quality level (4-step/8-step/40-step) - can use dropdown or default to "4-step"
4. Call `Submit Image Job` API
5. Store `job_id` in **App State** variable (you'll need this!)
6. Navigate to "Processing" page

---

### Step 2: Check Job Status (Polling)

**Create API Call: "Check Job Status"**

- **Method:** `GET`
- **Endpoint:** `/status/[job_id]`
  - In FlutterFlow, use variable: `/status/$jobId`
- **Add Variable:**
  - **Name:** `jobId`
  - **Type:** String
  - **Pass From:** App State variable

**Response Structure (Completed):**
```json
{
  "job_id": "abc123-def456-...",
  "status": "completed",
  "result_path": "qwen-4step_20241006_103125_s42_abc123.png",
  "result_seed": 42,
  "created_at": "2024-10-06T10:30:00",
  "completed_at": "2024-10-06T10:31:25"
}
```

**FlutterFlow Action Flow (on Processing Page):**
1. Add **Timer** widget (periodic action every 5 seconds)
2. Call `Check Job Status` API with `jobId` from App State
3. **Conditional Logic:**
   - If `status == "completed"` → Download image, show success
   - If `status == "failed"` → Show error message
   - If `status == "queued"` or `"processing"` → Keep polling
4. Cancel timer when status is `completed` or `failed`

**Note:** Add a loading indicator showing the current status to provide user feedback during processing.

---

### Step 3: Handle the Result

Once you get `status: "completed"`, download the edited image directly from the API:

- **GET** `/status/{job_id}/result`
- Returns the PNG image bytes (direct download)

In FlutterFlow, create a GET call that hits `/status/$jobId/result` and treat the response as a file/image download.

---

## FlutterFlow Implementation Details

Here's the recommended architecture for your FlutterFlow app:

### Pages

1. **Input Page**
   - Image picker
   - Text field (instruction)
   - "Submit" button

2. **Processing Page**
   - Loading animation
   - Status text ("Queued", "Processing", etc.)
   - Progress indicator
   - Timer for polling

3. **Result Page**
   - Display edited image
   - "Save" or "Share" buttons

### App State Variables

```dart
// Store these in App State
String currentJobId = "";
String jobStatus = "idle";
String resultImagePath = "";
int queuePosition = 0;
```

### Complete Flow

```
[Input Page]
    ↓
User clicks "Edit Image"
    ↓
API Call: Submit Image Job
    ↓
Store job_id in App State
    ↓
Navigate to Processing Page
    ↓
[Processing Page]
    ↓
Timer starts (every 5 sec)
    ↓
API Call: Check Job Status
    ↓
Update status text
    ↓
If completed → Navigate to Result Page
If failed → Show error
If queued/processing → Keep polling
    ↓
[Result Page]
    ↓
Display image
```

---

## API Call Examples (Copy-Paste Ready)

### Submit Job

**FlutterFlow API Call Configuration:**

```
Method: POST
Endpoint: /submit
Headers:
  X-API-Key: [your-api-key]
Body (Multipart):
  image: [ImageVariable]
  instruction: [InstructionText]
  seed: 42
```

**Expected Response:**
- Status Code: `200` (success) or `429` (queue full)
- Body: JSON with `job_id`

---

### Check Status

**FlutterFlow API Call Configuration:**

```
Method: GET
Endpoint: /status/[jobIdVariable]
Headers:
  X-API-Key: [your-api-key]
```

**Expected Response:**
- Status Code: `200` (found) or `404` (not found)
- Body: JSON with `status`, `result_path`, etc.

---

### Download Result Image

**FlutterFlow API Call Configuration:**

```
Method: GET
Endpoint: /status/[jobIdVariable]/result
Headers:
  X-API-Key: [your-api-key]
```

**Expected Response:**
- Status Code: `200` (success, PNG bytes)
- Status Code: `404` (job not found, or not completed yet)

---

### Get Queue Status (Optional)

Want to show users how busy the API is?

**FlutterFlow API Call Configuration:**

```
Method: GET
Endpoint: /queue
Headers:
  X-API-Key: [your-api-key]
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

Show this on your UI: "Queue: 4/10 jobs"

---

## Error Handling (Don't Skip This)

### HTTP Status Codes You'll See

| Code | Meaning | What to Do |
|------|---------|------------|
| `200` | Success | Continue |
| `400` | Bad Request | Show error: "Invalid image or instruction" |
| `401` | Unauthorized | Show error: "Invalid API key" (check your key!) |
| `404` | Not Found | Job doesn't exist (cleaned up after 1 hour) |
| `409` | Conflict | Preset mismatch (requested vs loaded), or server busy (loading/generating). Usually: omit `preset` and retry later if needed. |
| `429` | Too Many Requests | Queue is full, tell user to wait |
| `500` | Server Error | Show error: "Server error, try again" |

### FlutterFlow Error Handling

In your API call action:

1. **On Success (200):**
   - Parse response
   - Store job_id or show image

2. **On Failure (any error):**
   - Check `statusCode`
   - Show appropriate message
   - Don't just say "Error" - be specific!

**Example Error Messages:**
```dart
if (statusCode == 429) {
  showSnackBar("Queue is full. Please try again in a minute.");
} else if (statusCode == 400) {
  showSnackBar("Invalid image. Try a smaller file (max 10MB).");
} else if (statusCode == 401) {
  showSnackBar("Authentication failed. Contact support.");
} else {
  showSnackBar("Something went wrong. Try again.");
}
```

---

## Input Validation

Validate data before making API calls to avoid unnecessary errors and improve user experience.

### Image Requirements

- **Format:** JPG or PNG only
- **Size:** Max 10MB
- **Dimensions:** Max 2048x2048 pixels

**FlutterFlow Validation Steps:**
1. Check file size < 10MB
2. Verify file extension (.jpg, .jpeg, .png)
3. Display error message if invalid

### Instruction Requirements

- **Max length:** 500 characters
- **Required:** Cannot be empty

**FlutterFlow Validation Steps:**
1. Verify instruction.length > 0
2. Verify instruction.length <= 500
3. Trim whitespace before submission

---

## Performance Optimization

### 1. Polling Interval
- Poll every **5 seconds** (not faster)
- Reduces API load and battery consumption
- Provides adequate responsiveness

### 2. Queue Full Handling
- When receiving `429`, wait 30 seconds before retry
- Display "Service busy, please try again" message
- Implement exponential backoff for repeated failures

### 3. Result Caching
- Once you get the result, cache it locally
- Don't re-download the same image

### 4. Show Progress
- Display queue position to user
- Show estimated wait time
- Provide status updates during processing

---

## Pre-Production Testing Checklist

Test these scenarios before deploying to production:

- [ ] Submit valid image → Verify successful completion
- [ ] Submit oversized image (>10MB) → Verify 400 error response
- [ ] Submit with empty instruction → Verify validation works
- [ ] Submit when queue is full → Verify 429 error handling
- [ ] Poll for status during job processing → Verify status updates
- [ ] Complete full job workflow → Verify result retrieval
- [ ] Submit multiple jobs concurrently → Verify queueing behavior
- [ ] Test with slow network conditions → Verify timeout handling
- [ ] Test with incorrect API key → Verify 401 error response

---

## Common Implementation Issues

### Issue 1: Losing job_id Between Pages

**Problem:** Navigating to processing page without preserving job_id

**Solution:** Store job_id in App State before navigation
```dartString jobId = await submitJob();
setAppState('currentJobId', jobId);
navigateToProcessingPage();
```

### Issue 2: Excessive Polling

**Problem:** Polling status too frequently (every second)

**Solution:** Implement 5-second interval
```dart
Timer.periodic(Duration(seconds: 5), (timer) => checkStatus());
```

### Issue 3: Timer Not Canceled

**Problem:** Timer continues running after job completion

**Solution:** Cancel timer when status is terminal
```dart
if (status == "completed" || status == "failed") {
  timer.cancel();
}
```

### Issue 4: Missing Error Handling

**Problem:** Errors not caught or displayed to user

**Solution:** Implement comprehensive error handling
```dart
try {
  await submitJob();
} catch (e) {
  showError("Failed to submit: ${e.message}");
}
```

---

## Recommended UI Flow

### Input Screen
```
┌─────────────────────────────┐
│  📷 [Select Image]          │
│                             │
│  Instruction:               │
│  ┌─────────────────────┐   │
│  │ Make the sky blue   │   │
│  └─────────────────────┘   │
│                             │
│  [🎨 Edit Image Button]    │
└─────────────────────────────┘
```

### Processing Screen
```
┌─────────────────────────────┐
│       🔄 Processing...      │
│                             │
│   Status: Queued            │
│   Position: #3 in queue     │
│   Estimated: ~60 seconds    │
│                             │
│   ▓▓▓▓▓▓▓▓░░░░░░░░ 40%     │
└─────────────────────────────┘
```

### Result Screen
```
┌─────────────────────────────┐
│  ✅ Complete!               │
│                             │
│  [  Edited Image  ]         │
│                             │
│  [💾 Save] [📤 Share]      │
└─────────────────────────────┘
```

---

## Quick Reference

### API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/health` | GET | Check API status and configuration |
| `/models` | GET | List available models |
| `/submit` | POST | Submit job to queue |
| `/status/{job_id}` | GET | Check job status |
| `/status/{job_id}/result` | GET | Download completed image |
| `/queue` | GET | Get queue statistics |

### Job Status Values

- `queued` - Waiting in queue
- `processing` - Currently being processed
- `completed` - Successfully completed
- `failed` - Processing failed (see error field)

### Timing Guidelines

- **Model Selection:**
  - 4-step model: ~20 seconds per job (fast, good quality)
  - 8-step model: ~40 seconds per job (balanced)
  - 40-step model: ~3 minutes per job (highest quality)
- Model load time: ~20-60 seconds (one-time, when switching models)
- Poll interval: 5 seconds recommended
- Job cleanup: 1 hour after completion

---

## Support & Troubleshooting

### API Not Responding?

1. Check URL: `https://qwen.codeblazar.org/docs`
2. Verify internet connectivity
3. Check API key is correct
4. Contact your API administrator

### Jobs Taking Too Long?

- Check `/queue` endpoint
- If queue is full, wait and retry
- Normal processing: 20-60 seconds

### Getting 401 Errors?

- Your API key is incorrect
- Verify the key is copied correctly (no extra spaces)
- Header name must be exactly: `X-API-Key`

### Result Image Not Accessible?

- Use `GET /status/{job_id}/result` to download the image bytes once the job is completed
- If you get `404`, the job may not be completed yet (keep polling `/status/{job_id}`)

---

## Handling Multiple Users

For applications with multiple concurrent users:

1. **Each user gets their own job_id**
   - Don't share job_ids between users!
   
2. **Store job_id per user session**
   - Use user-specific storage
   
3. **Handle queue full gracefully**
   - Show message: "Service is busy, try again"
   
4. **Don't spam the API**
   - Rate limit your own app
   - Max 1 submission per user per minute

---

## Need Help?

**Documentation:**
- API documentation: `api/README.md`
- Main README: `README.md`
- Swagger UI: `https://qwen.codeblazar.org/docs`

**Common Issues:**
- Timeouts → Use queue-based workflow
- 429 errors → Queue is full, retry later
- 400 errors → Check image size/format
- 401 errors → Check API key

**Contact:**
- API Administrator (Pete) for API key issues
- Check GitHub repository for updates

---

## Summary

**Quick Reference:**

1. **Create API Group** with base URL (`https://qwen.codeblazar.org/api/v1`) and API key header
2. **POST to `/submit`** with image + instruction → Receive `job_id`
3. **Poll GET `/status/{job_id}`** every 5 seconds → Monitor status
4. **When `status == "completed"`** → Process result
5. **Handle errors:** 400 (invalid input), 429 (queue full), 401 (unauthorized)

**Critical Requirements:**
- Poll at 5-second intervals (not faster)
- Cancel timer when job reaches terminal status (completed/failed)
- Implement comprehensive error handling
- Validate inputs before submission
- Display progress indicators to users
- Handle queue full scenarios gracefully
- Test all error scenarios before production deployment

---

**Note:** Thorough testing of error handling scenarios is critical for production deployment.
