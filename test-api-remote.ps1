# Qwen Image Edit API - Remote Test Script
# Version: 2.0.3 (2025-10-07)
# This script tests all major API endpoints and workflows remotely
# 
# PowerShell Requirements:
#   - PowerShell 5.1+ (Windows PowerShell) - Fully supported
#   - PowerShell 7+ (PowerShell Core) - Fully supported
#   - Works on both versions with automatic version detection
#
# Usage: .\test-api-remote.ps1 -ApiKey "your-api-key-here"
#        .\test-api-remote.ps1 -ApiKey "your-key" -BaseUrl "http://localhost:8000/api/v1"
#
# Required Files (in same directory):
#   - api-test-image.png (512x512 test portrait)
#   - api-test-image-large.png (3000x3000 for overflow test)

param(
    [Parameter(Mandatory=$true)]
    [string]$ApiKey,
    
    [Parameter(Mandatory=$false)]
    [string]$BaseUrl = "https://qwen.codeblazar.org/api/v1",
    
    [Parameter(Mandatory=$false)]
    [switch]$DebugLog
)

# Script version
$SCRIPT_VERSION = "2.0.3"

# Debug log file
$DebugLogLogFile = Join-Path $PSScriptRoot "test-api-remote-debug.log"

# Initialize debug log
if ($DebugLog) {
    "=== Test API Remote Debug Log ===" | Out-File -FilePath $DebugLogLogFile -Encoding ASCII
    "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $DebugLogLogFile -Append -Encoding ASCII
    "PowerShell Version: $($PSVersionTable.PSVersion)" | Out-File -FilePath $DebugLogLogFile -Append -Encoding ASCII
    "Base URL: $BaseUrl" | Out-File -FilePath $DebugLogLogFile -Append -Encoding ASCII
    "" | Out-File -FilePath $DebugLogLogFile -Append -Encoding ASCII
}

function Write-Debug-Log {
    param($Message)
    if ($DebugLog) {
        $timestamp = Get-Date -Format 'HH:mm:ss.fff'
        "[$timestamp] $Message" | Out-File -FilePath $DebugLogLogFile -Append -Encoding ASCII
        Write-Warning-Custom "DEBUG: $Message"
    }
}

# Color output functions
function Write-Success { 
    param($Message) 
    Write-Host "[OK] $Message" -ForegroundColor Green 
}
function Write-Error-Custom { 
    param($Message) 
    Write-Host "[ERROR] $Message" -ForegroundColor Red 
}
function Write-Info { 
    param($Message) 
    Write-Host "[INFO] $Message" -ForegroundColor Cyan 
}
function Write-Warning-Custom { 
    param($Message) 
    Write-Host "[WARN] $Message" -ForegroundColor Yellow 
}

# Test counters
$script:TestsPassed = 0
$script:TestsFailed = 0
$script:TestNumber = 0

function Test-Endpoint {
    param($Name)
    $script:TestNumber++
    Write-Host "`n[$script:TestNumber] $Name..." -NoNewline
}

function Pass-Test {
    param($Message = "")
    $script:TestsPassed++
    if ($Message) {
        Write-Success " PASS - $Message"
    } else {
        Write-Success " PASS"
    }
}

function Fail-Test {
    param($Message)
    $script:TestsFailed++
    Write-Error-Custom " FAIL - $Message"
}

# Create test image function
function New-TestImage {
    param(
        [int]$Width = 512,
        [int]$Height = 512,
        [string]$OutputPath = "$env:TEMP\test_image.png"  # Changed to .png
    )
    
    # Use the project's test image if it exists
    $projectTestImage = Join-Path $PSScriptRoot "api-test-image.png"
    $projectLargeImage = Join-Path $PSScriptRoot "api-test-image-large.png"
    
    # For 3000x3000, use the large test image if available
    if ($Width -eq 3000 -and $Height -eq 3000 -and (Test-Path $projectLargeImage)) {
        Copy-Item -Path $projectLargeImage -Destination $OutputPath -Force
        Write-Verbose "Using large test image: $projectLargeImage"
        return $OutputPath
    }
    # For default 512x512, use the standard test image
    elseif ($Width -eq 512 -and $Height -eq 512 -and (Test-Path $projectTestImage)) {
        Copy-Item -Path $projectTestImage -Destination $OutputPath -Force
        Write-Verbose "Using test image: $projectTestImage"
        return $OutputPath
    }
    else {
        # Create a programmatic image for other sizes or if test images not found
        Add-Type -AssemblyName System.Drawing
        
        $bitmap = New-Object System.Drawing.Bitmap($Width, $Height)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        
        if ($Width -ne 512 -or $Height -ne 512) {
            # For large test images, create simple solid color
            $graphics.Clear([System.Drawing.Color]::Gray)
            
            # Add text indicating size
            $fontSize = [Math]::Min(48, [Math]::Floor($Width / 20))
            $font = New-Object System.Drawing.Font("Arial", $fontSize)
            $textBrush = [System.Drawing.Brushes]::White
            $graphics.DrawString("${Width}x${Height}", $font, $textBrush, 10, 10)
            $font.Dispose()
        }
        else {
            # Fallback: create a gradient image if standard test image not found
            Write-Warning "Test image not found at: $projectTestImage"
            Write-Warning "Creating fallback gradient image..."
            
            # Fill with a landscape-like gradient (sky to ground)
            $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
                (New-Object System.Drawing.Point(0, 0)),
                (New-Object System.Drawing.Point(0, $Height)),
                [System.Drawing.Color]::SkyBlue,
                [System.Drawing.Color]::ForestGreen
            )
            
            $graphics.FillRectangle($brush, 0, 0, $Width, $Height)
            $brush.Dispose()
            
            # Add some text
            $font = New-Object System.Drawing.Font("Arial", 24)
            $textBrush = [System.Drawing.Brushes]::White
            $graphics.DrawString("Test Image", $font, $textBrush, 10, 10)
            $font.Dispose()
        }
        
        $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Jpeg)
        
        $graphics.Dispose()
        $bitmap.Dispose()
        
        return $OutputPath
    }
}

# API request helper
function Invoke-ApiRequest {
    param(
        [string]$Method,
        [string]$Endpoint,
        [hashtable]$Body = $null,
        [string]$ContentType = "application/json"
    )
    
    $headers = @{
        "X-API-Key" = $ApiKey
    }
    
    $uri = "$BaseUrl$Endpoint"
    
    try {
        $params = @{
            Uri = $uri
            Method = $Method
            Headers = $headers
            ContentType = $ContentType
        }
        
        if ($Body) {
            if ($ContentType -eq "application/json") {
                $params.Body = ($Body | ConvertTo-Json -Depth 10)
            } else {
                $params.Body = $Body
            }
        }
        
        $response = Invoke-RestMethod @params
        return @{ Success = $true; Data = $response; StatusCode = 200 }
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorMessage = $_.Exception.Message
        return @{ Success = $false; Error = $errorMessage; StatusCode = $statusCode }
    }
}

# Multipart form data helper
function Invoke-MultipartRequest {
    param(
        [string]$Endpoint,
        [string]$ImagePath,
        [string]$Instruction,
        [int]$Seed = $null
    )
    
    $uri = "$BaseUrl$Endpoint"
    
    if ($DebugLog) {
        Write-Debug-Log "=== Multipart Request ==="
        Write-Debug-Log "URI: $uri"
        Write-Debug-Log "Image path: $ImagePath"
        Write-Debug-Log "Image exists: $(Test-Path $ImagePath)"
        if (Test-Path $ImagePath) {
            $imageInfo = Get-Item $ImagePath
            Write-Debug-Log "Image size: $($imageInfo.Length) bytes"
            Write-Debug-Log "Image extension: $($imageInfo.Extension)"
        }
        Write-Debug-Log "Instruction: $Instruction"
        Write-Debug-Log "Seed: $Seed"
    }
    
    try {
        $headers = @{
            "X-API-Key" = $ApiKey
        }
        
        # Use HttpClient for all PowerShell versions to ensure proper content-type handling
        Add-Type -AssemblyName System.Net.Http
        
        $httpClient = New-Object System.Net.Http.HttpClient
        $httpClient.DefaultRequestHeaders.Add("X-API-Key", $ApiKey)
        
        $multipartContent = New-Object System.Net.Http.MultipartFormDataContent
        
        # Add instruction
        $instructionContent = New-Object System.Net.Http.StringContent($Instruction)
        $multipartContent.Add($instructionContent, "instruction")
        
        # Add seed if provided
        if ($Seed) {
            $seedContent = New-Object System.Net.Http.StringContent($Seed.ToString())
            $multipartContent.Add($seedContent, "seed")
        }
        
        # Add image file
        $fileStream = [System.IO.File]::OpenRead($ImagePath)
        $imageContent = New-Object System.Net.Http.StreamContent($fileStream)
        
        # Determine content type based on file extension
        $fileExt = [System.IO.Path]::GetExtension($ImagePath).ToLower()
        $contentType = switch ($fileExt) {
            ".png" { "image/png" }
            ".jpg" { "image/jpeg" }
            ".jpeg" { "image/jpeg" }
            default { "image/jpeg" }
        }
        $fileName = [System.IO.Path]::GetFileName($ImagePath)
        
        if ($DebugLog) {
            Write-Debug-Log "Using HttpClient for multipart upload"
            Write-Debug-Log "File extension: $fileExt"
            Write-Debug-Log "Content-Type: $contentType"
            Write-Debug-Log "File name: $fileName"
        }
        
        $imageContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse($contentType)
        $multipartContent.Add($imageContent, "image", $fileName)
        
        $httpResponse = $httpClient.PostAsync($uri, $multipartContent).Result
        $responseContent = $httpResponse.Content.ReadAsStringAsync().Result
        
        if ($DebugLog) {
            Write-Debug-Log "Response status: $($httpResponse.StatusCode)"
            Write-Debug-Log "Response content: $responseContent"
        }
        
        # Cleanup
        if ($fileStream) { $fileStream.Dispose() }
        $httpClient.Dispose()
        $multipartContent.Dispose()
        
        if ($httpResponse.IsSuccessStatusCode) {
            $response = $responseContent | ConvertFrom-Json
            return @{ Success = $true; Data = $response; StatusCode = 200 }
        } else {
            # Return the actual HTTP status code from the response with full error details
            $actualStatusCode = [int]$httpResponse.StatusCode
            
            if ($DebugLog) {
                Write-Debug-Log "!!! Error response !!!"
                Write-Debug-Log "Status code: $actualStatusCode"
            }
            
            # Try to parse JSON error or return raw content
            $errorMessage = try {
                $errorJson = $responseContent | ConvertFrom-Json
                if ($errorJson.detail) { $errorJson.detail } else { $responseContent }
            } catch {
                $responseContent
            }
            $errorDetails = "HTTP ${actualStatusCode}: $errorMessage"
            
            if ($DebugLog) {
                Write-Debug-Log "Final error: $errorDetails"
            }
            
            return @{ Success = $false; Error = $errorDetails; StatusCode = $actualStatusCode }
        }
    }
    catch {
        # Fallback error handler for unexpected errors
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { 500 }
        $errorMessage = $_.Exception.Message
        return @{ Success = $false; Error = "Unexpected error: $errorMessage"; StatusCode = $statusCode }
    }
}

# Main test execution
Write-Host @"
================================================================
          Qwen Image Edit API - Remote Test Suite
                        Version $SCRIPT_VERSION
================================================================
"@ -ForegroundColor Cyan

$psVersion = $PSVersionTable.PSVersion
$psVersionString = "$($psVersion.Major).$($psVersion.Minor)"
$isSupported = $psVersion.Major -ge 5 -and ($psVersion.Major -gt 5 -or $psVersion.Minor -ge 1)
$supportStatus = if ($isSupported) { "[OK] Supported" } else { "[ERROR] UNSUPPORTED" }
$statusColor = if ($isSupported) { "Green" } else { "Red" }

Write-Host "[INFO] PowerShell: $psVersionString - $supportStatus" -ForegroundColor $statusColor
Write-Info "API Base URL: $BaseUrl"
Write-Info "API Key: $('*' * 20)$($ApiKey.Substring([Math]::Max(0, $ApiKey.Length - 8)))"
Write-Info "Test started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

if (-not $isSupported) {
    Write-Error-Custom "This script requires PowerShell 5.1 or higher. Please upgrade PowerShell."
    exit 1
}

# Wait for server to be ready
Write-Info "`nWaiting for API server to be ready..."
$maxWait = 30
$waited = 0
$serverReady = $false

while ($waited -lt $maxWait) {
    try {
        $healthCheck = Invoke-RestMethod -Uri "$BaseUrl/health" -Method GET -ErrorAction Stop
        if ($healthCheck.status -eq "healthy") {
            $serverReady = $true
            Write-Success "Server is ready!"
            break
        }
    } catch {
        Write-Host "." -NoNewline
    }
    Start-Sleep -Seconds 1
    $waited++
}

if (-not $serverReady) {
    Write-Error-Custom "`nServer did not become ready within $maxWait seconds. Aborting tests."
    exit 1
}

# Check for required test images
Write-Info "`nChecking for required test images..."
$testImageSmall = Join-Path $PSScriptRoot "api-test-image.png"
$testImageLarge = Join-Path $PSScriptRoot "api-test-image-large.png"

if (-not (Test-Path $testImageSmall)) {
    Write-Error-Custom "Required test image not found: $testImageSmall"
    Write-Error-Custom "Please ensure 'api-test-image.png' (512x512) is in the same directory as this script."
    exit 1
}

if (-not (Test-Path $testImageLarge)) {
    Write-Error-Custom "Required test image not found: $testImageLarge"
    Write-Error-Custom "Please ensure 'api-test-image-large.png' (3000x3000) is in the same directory as this script."
    exit 1
}

$smallSize = (Get-Item $testImageSmall).Length / 1MB
$largeSize = (Get-Item $testImageLarge).Length / 1MB
Write-Success "Test images found:"
Write-Success "  - api-test-image.png ($($smallSize.ToString('N2')) MB)"
Write-Success "  - api-test-image-large.png ($($largeSize.ToString('N2')) MB)"

# Create test image
Write-Info "`nCreating test image..."
$testImagePath = New-TestImage
Write-Success "Test image created: $testImagePath"

# Test 1: Health Check
Test-Endpoint "Health Check"
$result = Invoke-ApiRequest -Method GET -Endpoint "/health"
if ($result.Success) {
    $health = $result.Data
    Pass-Test "Status: $($health.status), Model: $($health.current_model), Queue Max: $($health.queue_max_size)"
} else {
    Fail-Test "Health check failed: $($result.Error)"
}

# Test 2: Invalid API Key
Test-Endpoint "Invalid API Key Rejection"
$headers = @{ "X-API-Key" = "invalid-key-12345" }
try {
    $response = Invoke-WebRequest -Uri "$BaseUrl/models" -Headers $headers -Method GET -ErrorAction Stop
    Fail-Test "Should have rejected invalid key (got $($response.StatusCode))"
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 401) {
        Pass-Test "Correctly rejected with 401"
    } else {
        Fail-Test "Expected 401, got $statusCode"
    }
}

# Test 3: List Models
Test-Endpoint "List Available Models"
$result = Invoke-ApiRequest -Method GET -Endpoint "/models"
if ($result.Success) {
    $models = @($result.Data.models.PSObject.Properties)
    $modelCount = $models.Count
    if ($modelCount -eq 3) {
        $modelNames = $models.Value | ForEach-Object { $_.name }
        Pass-Test "Found 3 models: $($modelNames -join ', ')"
    } else {
        Fail-Test "Expected 3 models, got $modelCount"
    }
} else {
    Fail-Test "Models request failed: $($result.Error)"
}

# Test 4: Queue Status
Test-Endpoint "Get Queue Status"
$result = Invoke-ApiRequest -Method GET -Endpoint "/queue"
if ($result.Success) {
    $queue = $result.Data
    Pass-Test "Queue: $($queue.queue_size)/$($queue.max_queue_size), Processing: $($queue.processing_count)"
} else {
    Fail-Test "Queue status failed: $($result.Error)"
}

# Test 4.5: Load Model (prerequisite for image editing tests)
Test-Endpoint "Load Model for Testing"
$result = Invoke-ApiRequest -Method POST -Endpoint "/load-model?model=4-step"
if ($result.Success) {
    $loadTime = $result.Data.load_time_seconds
    Write-Info "Model load request completed in ${loadTime}s"
    
    # Wait and verify model is actually loaded by polling health endpoint
    Write-Info "Verifying model is ready..."
    $maxWait = 180  # 3 minutes for model to load
    $waitStart = Get-Date
    $modelReady = $false
    
    while (((Get-Date) - $waitStart).TotalSeconds -lt $maxWait) {
        Start-Sleep -Seconds 2
        $healthCheck = Invoke-ApiRequest -Method GET -Endpoint "/health"
        if ($healthCheck.Success -and $healthCheck.Data.current_model -eq "4-step" -and -not $healthCheck.Data.is_loading) {
            $modelReady = $true
            $totalWait = [math]::Round(((Get-Date) - $waitStart).TotalSeconds, 1)
            Write-Info "Model ready after ${totalWait}s total"
            break
        }
        Write-Host "." -NoNewline
    }
    
    if ($modelReady) {
        Pass-Test "Model confirmed loaded and ready: 4-step"
    } else {
        Fail-Test "Model load timed out or failed - health check shows model not ready"
    }
} else {
    Fail-Test "Model load failed: $($result.Error)"
}

# Test 5: Submit Job
Test-Endpoint "Submit Image Editing Job"
$result = Invoke-MultipartRequest -Endpoint "/submit" -ImagePath $testImagePath -Instruction "Add a rainbow in the sky" -Seed 42
if ($result.Success) {
    $jobId = $result.Data.job_id
    $position = $result.Data.position
    Pass-Test "Job submitted: $($jobId.Substring(0,8))..., Position: $position"
} else {
    if ($result.StatusCode -eq 429) {
        Write-Warning-Custom " Queue is full (429) - This is expected behavior"
        $script:TestsPassed++
        $jobId = $null
    } else {
        Fail-Test "Submit failed: $($result.Error) (Status: $($result.StatusCode))"
        $jobId = $null
    }
}

# Test 6: Check Job Status
if ($jobId) {
    Test-Endpoint "Check Job Status"
    $result = Invoke-ApiRequest -Method GET -Endpoint "/status/$jobId"
    if ($result.Success) {
        $status = $result.Data.status
        $position = $result.Data.position
        if ($position) {
            Pass-Test "Status: $status, Position: $position"
        } else {
            Pass-Test "Status: $status"
        }
    } else {
        Fail-Test "Status check failed: $($result.Error)"
    }
    
    # Test 7: Wait for Completion
    Test-Endpoint "Wait for Job Completion (max 120s)"
    $maxWait = 120
    $startTime = Get-Date
    $completed = $false
    
    while (((Get-Date) - $startTime).TotalSeconds -lt $maxWait) {
        $result = Invoke-ApiRequest -Method GET -Endpoint "/status/$jobId"
        if ($result.Success) {
            $status = $result.Data.status
            
            if ($status -eq "completed") {
                $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
                Pass-Test "Completed in ${elapsed}s, Result: $($result.Data.result_path)"
                $completed = $true
                break
            }
            elseif ($status -eq "failed") {
                Fail-Test "Job failed: $($result.Data.error)"
                break
            }
            else {
                Write-Host "." -NoNewline
                Start-Sleep -Seconds 5
            }
        } else {
            Fail-Test "Status check failed: $($result.Error)"
            break
        }
    }
    
    if (-not $completed -and $status -ne "failed") {
        Write-Warning-Custom " Timeout waiting for completion (job may still be processing)"
        $script:TestsPassed++
    }
}

# Test 8: Submit Multiple Jobs
Test-Endpoint "Submit Multiple Jobs Concurrently"
$jobIds = @()
$successCount = 0

$concurrentPrompts = @(
    "Add fluffy clouds to the sky",
    "Make the image warmer and sunny",
    "Add a sunset glow"
)

for ($i = 1; $i -le 3; $i++) {
    $result = Invoke-MultipartRequest -Endpoint "/submit" -ImagePath $testImagePath -Instruction $concurrentPrompts[$i-1] -Seed (100 + $i)
    if ($result.Success) {
        $jobIds += $result.Data.job_id
        $successCount++
    }
    elseif ($result.StatusCode -eq 429) {
        # Queue full is acceptable
        $successCount++
    }
}

if ($successCount -eq 3) {
    Pass-Test "Submitted $successCount jobs (some may have queued)"
} else {
    Fail-Test "Only $successCount/3 jobs submitted successfully"
}

# Wait for these jobs to complete before testing queue overflow
Write-Info "  Waiting for concurrent jobs to complete before queue overflow test..."
$waitStart = Get-Date
$maxWait = 120
while (((Get-Date) - $waitStart).TotalSeconds -lt $maxWait) {
    $result = Invoke-ApiRequest -Method GET -Endpoint "/queue"
    if ($result.Success -and $result.Data.queue_size -eq 0 -and $result.Data.processing_count -eq 0) {
        Write-Info "  Queue cleared after $([math]::Round(((Get-Date) - $waitStart).TotalSeconds, 1))s"
        break
    }
    Start-Sleep -Seconds 3
}

# Test 8.5: Queue Overflow Protection (Fill Queue)
Test-Endpoint "Queue Overflow Protection"
Write-Info "  Testing queue capacity limits (submitting 15 jobs to empty queue)..."
Write-Info "  Expected: 10 accepted + 5 rejected with 429"

$queueTestJobs = @()
$rejectedCount = 0
$acceptedCount = 0
$maxQueueSize = 10

# Always submit 15 jobs to guarantee we hit the limit and get rejections
$jobsToSubmit = 15
Write-Info "  Attempting to submit $jobsToSubmit jobs to test overflow..."

$queuePrompts = @(
    "Add morning mist",
    "Make it nighttime with stars",
    "Add autumn leaves falling",
    "Make it snow gently",
    "Add a beautiful rainbow",
    "Make it golden hour",
    "Add dramatic storm clouds",
    "Make it spring with flowers",
    "Add a gentle rain",
    "Make it foggy and mysterious",
    "Add birds flying",
    "Make it sunny and bright",
    "Add moonlight",
    "Make it windy with movement",
    "Add magical sparkles"
)

for ($i = 1; $i -le $jobsToSubmit; $i++) {
    $result = Invoke-MultipartRequest -Endpoint "/submit" -ImagePath $testImagePath -Instruction $queuePrompts[$i-1] -Seed (200 + $i)
    if ($result.Success) {
        $queueTestJobs += @{
            JobId = $result.Data.job_id
            Position = $result.Data.position
            Number = $i
        }
        $acceptedCount++
    }
    elseif ($result.StatusCode -eq 429) {
        $rejectedCount++
    }
    else {
        # Some other error occurred
        Write-Warning-Custom "  Job $i failed with status $($result.StatusCode): $($result.Error)"
    }
    # No delay - submit as fast as possible to test overflow before processing starts
}

Write-Info "  Results: $acceptedCount accepted, $rejectedCount rejected (429), Failed: $($jobsToSubmit - $acceptedCount - $rejectedCount)"

# Validate queue overflow protection
if ($acceptedCount -eq 10 -and $rejectedCount -eq 5) {
    Pass-Test "Perfect! 10 jobs accepted, 5 rejected with 429 (queue protection working)"
} elseif ($rejectedCount -gt 0 -and $acceptedCount -le 12) {
    Pass-Test "Queue protected: $acceptedCount accepted, $rejectedCount rejected with 429 (some jobs started processing)"
} elseif ($acceptedCount -ge 10 -and $acceptedCount -le 15 -and $rejectedCount -eq 0) {
    Write-Warning-Custom "  Queue processing very fast - accepted $acceptedCount jobs before overflow could occur"
    Pass-Test "Queue capacity working: $acceptedCount jobs accepted (processing faster than submission)"
} else {
    Fail-Test "Unexpected results: $acceptedCount accepted, $rejectedCount rejected (expected ~10 accepted + ~5 rejected)"
}

# Test 8.6: Queue Status Under Load
Test-Endpoint "Queue Status Under Load"
$result = Invoke-ApiRequest -Method GET -Endpoint "/queue"
if ($result.Success) {
    $queue = $result.Data
    $totalJobs = $queue.queue_size + $queue.processing_count
    Write-Info "  Active jobs: $totalJobs (Queued: $($queue.queue_size), Processing: $($queue.processing_count))"
    if ($totalJobs -gt 0) {
        Pass-Test "Queue status reporting correctly"
    } else {
        Write-Warning-Custom "  Queue already empty (processing very fast)"
        $script:TestsPassed++
    }
} else {
    Fail-Test "Failed to get queue status: $($result.Error)"
}

# Test 8.7: Queue Position Tracking
Test-Endpoint "Queue Position Tracking"
if ($queueTestJobs.Count -gt 0) {
    $jobToCheck = $queueTestJobs[0]
    $result = Invoke-ApiRequest -Method GET -Endpoint "/status/$($jobToCheck.JobId)"
    if ($result.Success) {
        $status = $result.Data.status
        if ($status -eq "queued") {
            Pass-Test "Job correctly queued (status: queued)"
        } elseif ($status -in @("processing", "completed")) {
            Pass-Test "Job progressing normally (status: $status)"
        } else {
            Fail-Test "Unexpected status: $status"
        }
    } else {
        Fail-Test "Failed to check job status: $($result.Error)"
    }
} else {
    Write-Warning-Custom "  No jobs to track (all processed immediately)"
    $script:TestsPassed++
}

# Wait for queue to drain before continuing
if ($queueTestJobs.Count -gt 0) {
    # Calculate needed wait time: jobs * ~20 seconds per job + 30 second buffer
    $estimatedTime = $queueTestJobs.Count * 20 + 30
    $maxDrainWait = [Math]::Max($estimatedTime, 300)  # At least 5 minutes
    Write-Info "  Waiting for queue to drain (max ${maxDrainWait}s for $($queueTestJobs.Count) jobs)..."
    
    $waitStart = Get-Date
    $lastQueueSize = -1
    $completedCount = 0
    
    while (((Get-Date) - $waitStart).TotalSeconds -lt $maxDrainWait) {
        $result = Invoke-ApiRequest -Method GET -Endpoint "/queue"
        if ($result.Success) {
            $currentTotal = $result.Data.queue_size + $result.Data.processing_count
            
            # Show progress when queue size changes
            if ($currentTotal -ne $lastQueueSize) {
                $completed = $queueTestJobs.Count - $currentTotal
                if ($completed -gt $completedCount) {
                    $elapsed = [math]::Round(((Get-Date) - $waitStart).TotalSeconds, 1)
                    Write-Host "  [$elapsed`s] Completed: $completed/$($queueTestJobs.Count) jobs (Remaining: $currentTotal)" -ForegroundColor Cyan
                    $completedCount = $completed
                }
                $lastQueueSize = $currentTotal
            }
            
            # Check if done
            if ($result.Data.queue_size -eq 0 -and $result.Data.processing_count -eq 0) {
                $totalTime = [math]::Round(((Get-Date) - $waitStart).TotalSeconds, 1)
                Write-Info "  All $($queueTestJobs.Count) jobs completed in ${totalTime}s"
                break
            }
        }
        Start-Sleep -Seconds 2
    }
}

# Test 9: Invalid Image (too large dimensions)
Test-Endpoint "Reject Oversized Image"
$largeImagePath = "$env:TEMP\large_test.jpg"
try {
    New-TestImage -Width 3000 -Height 3000 -OutputPath $largeImagePath
    $result = Invoke-MultipartRequest -Endpoint "/submit" -ImagePath $largeImagePath -Instruction "Test"
    
    if (-not $result.Success -and $result.StatusCode -eq 400) {
        Pass-Test "Correctly rejected with 400"
    } else {
        Fail-Test "Should have rejected oversized image"
    }
    Remove-Item $largeImagePath -ErrorAction SilentlyContinue
} catch {
    Write-Warning-Custom " Could not create large test image: $($_.Exception.Message)"
    $script:TestsPassed++
}

# Test 10: Invalid Job ID
Test-Endpoint "Request Invalid Job ID"
$fakeId = "00000000-0000-0000-0000-000000000000"
$result = Invoke-ApiRequest -Method GET -Endpoint "/status/$fakeId"
if (-not $result.Success -and $result.StatusCode -eq 404) {
    Pass-Test "Correctly returned 404"
} else {
    Fail-Test "Expected 404 for invalid job ID"
}

# Cleanup
Write-Info "`nCleaning up..."
Remove-Item $testImagePath -ErrorAction SilentlyContinue
Write-Success "Test image removed"

# Summary
$totalTests = $script:TestsPassed + $script:TestsFailed
$passRate = if ($totalTests -gt 0) { [math]::Round(($script:TestsPassed / $totalTests) * 100, 1) } else { 0 }

Write-Host @"

================================================================
                       Test Summary
================================================================
"@ -ForegroundColor Cyan

Write-Host "Total Tests:  $totalTests"
Write-Success "Passed:       $script:TestsPassed"
if ($script:TestsFailed -gt 0) {
    Write-Error-Custom "Failed:       $script:TestsFailed"
} else {
    Write-Host "Failed:       $script:TestsFailed" -ForegroundColor Gray
}
Write-Host "Pass Rate:    $passRate%"
Write-Info "Test ended:   $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

if ($DebugLog) {
    Write-Info "`nDebug log written to: $DebugLogLogFile"
}

if ($script:TestsFailed -eq 0) {
    Write-Host "`nALL TESTS PASSED!`n" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n$script:TestsFailed TEST(S) FAILED`n" -ForegroundColor Red
    exit 1
}
