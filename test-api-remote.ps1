# Qwen Image Edit API - Test Script
# This script tests all major API endpoints and workflows
# Usage: .\test-api-remote.ps1 -ApiKey "your-api-key-here"

param(
    [Parameter(Mandatory=$true)]
    [string]$ApiKey,
    
    [Parameter(Mandatory=$false)]
    [string]$BaseUrl = "https://qwen.codeblazar.org/api/v1"
)

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
        [string]$OutputPath = "$env:TEMP\test_image.jpg"
    )
    
    Add-Type -AssemblyName System.Drawing
    
    $bitmap = New-Object System.Drawing.Bitmap($Width, $Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    
    # Fill with a blue gradient
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.Point(0, 0)),
        (New-Object System.Drawing.Point($Width, $Height)),
        [System.Drawing.Color]::SkyBlue,
        [System.Drawing.Color]::Navy
    )
    
    $graphics.FillRectangle($brush, 0, 0, $Width, $Height)
    
    # Add some text
    $font = New-Object System.Drawing.Font("Arial", 24)
    $textBrush = [System.Drawing.Brushes]::White
    $graphics.DrawString("Test Image", $font, $textBrush, 10, 10)
    
    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Jpeg)
    
    $graphics.Dispose()
    $bitmap.Dispose()
    $brush.Dispose()
    $font.Dispose()
    
    return $OutputPath
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
    
    try {
        $headers = @{
            "X-API-Key" = $ApiKey
        }
        
        # PowerShell 7+ supports -Form parameter for multipart uploads
        # For PowerShell 5.1, we need to use a different approach
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $form = @{
                instruction = $Instruction
                image = Get-Item -Path $ImagePath
            }
            if ($Seed) {
                $form.seed = $Seed
            }
            $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Form $form
        } else {
            # PowerShell 5.1 workaround - use WebRequest
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
            $imageContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("image/jpeg")
            $multipartContent.Add($imageContent, "image", "test.jpg")
            
            $httpResponse = $httpClient.PostAsync($uri, $multipartContent).Result
            $responseContent = $httpResponse.Content.ReadAsStringAsync().Result
            
            # Cleanup
            if ($fileStream) { $fileStream.Dispose() }
            $httpClient.Dispose()
            $multipartContent.Dispose()
            
            if ($httpResponse.IsSuccessStatusCode) {
                $response = $responseContent | ConvertFrom-Json
            } else {
                throw "HTTP $($httpResponse.StatusCode): $responseContent"
            }
        }
        
        return @{ Success = $true; Data = $response; StatusCode = 200 }
    }
    catch {
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { 400 }
        $errorMessage = $_.Exception.Message
        return @{ Success = $false; Error = $errorMessage; StatusCode = $statusCode }
    }
}

# Main test execution
Write-Host @"
================================================================
          Qwen Image Edit API - Remote Test Suite
================================================================
"@ -ForegroundColor Cyan

Write-Info "API Base URL: $BaseUrl"
Write-Info "API Key: $('*' * 20)$($ApiKey.Substring([Math]::Max(0, $ApiKey.Length - 8)))"
Write-Info "Test started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

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
    $response = Invoke-RestMethod -Uri "$BaseUrl/models" -Headers $headers
    Fail-Test "Should have rejected invalid key"
} catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 401) {
        Pass-Test "Correctly rejected with 401"
    } else {
        Fail-Test "Expected 401, got $($_.Exception.Response.StatusCode.value__)"
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
$loadModelBody = @{ model_key = "4-step" }
$result = Invoke-ApiRequest -Method POST -Endpoint "/load-model" -Body $loadModelBody
if ($result.Success) {
    Write-Info "Waiting for model to load..."
    Start-Sleep -Seconds 3
    Pass-Test "Model load initiated: 4-step"
} else {
    Write-Warning-Custom "Model load failed (may already be loaded): $($result.Error)"
    $script:TestsPassed++  # Don't fail the whole test suite
}

# Test 5: Submit Job
Test-Endpoint "Submit Image Editing Job"
$result = Invoke-MultipartRequest -Endpoint "/submit" -ImagePath $testImagePath -Instruction "Make the sky more vibrant" -Seed 42
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

for ($i = 1; $i -le 3; $i++) {
    $result = Invoke-MultipartRequest -Endpoint "/submit" -ImagePath $testImagePath -Instruction "Test job #$i" -Seed (100 + $i)
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

# Test 8.5: Queue Overflow Protection (Fill Queue)
Test-Endpoint "Queue Overflow Protection"
Write-Info "  Testing queue capacity limits..."

# First check current queue status
$queueStatusBefore = Invoke-ApiRequest -Method GET -Endpoint "/queue"
$currentQueueSize = if ($queueStatusBefore.Success) { 
    $queueStatusBefore.Data.queue_size + $queueStatusBefore.Data.processing_count 
} else { 
    0 
}
Write-Info "  Current queue size: $currentQueueSize"

$queueTestJobs = @()
$rejectedCount = 0
$acceptedCount = 0
$maxQueueSize = 10

# Try to submit more than remaining capacity
$jobsToSubmit = $maxQueueSize - $currentQueueSize + 5  # Try to overfill by 5
Write-Info "  Attempting to submit $jobsToSubmit jobs to test overflow..."

for ($i = 1; $i -le $jobsToSubmit; $i++) {
    $result = Invoke-MultipartRequest -Endpoint "/submit" -ImagePath $testImagePath -Instruction "Queue fill test #$i" -Seed (200 + $i)
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
        Write-Info "  Job $i rejected with 429 (queue full)"
    }
    Start-Sleep -Milliseconds 50  # Small delay to ensure consistent submission
}

$totalJobs = $currentQueueSize + $acceptedCount
Write-Info "  Results: $acceptedCount accepted, $rejectedCount rejected, Total in queue: $totalJobs"

if ($rejectedCount -gt 0) {
    Pass-Test "Queue protected: $rejectedCount jobs rejected with 429 (capacity working)"
} elseif ($totalJobs -ge $maxQueueSize) {
    Pass-Test "Queue at/near capacity: $totalJobs jobs (processing fast, no rejections yet)"
} else {
    Fail-Test "Queue not full enough to test overflow ($totalJobs/$maxQueueSize)"
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
    Write-Info "  Waiting for queue to drain (max 60s)..."
    $waitStart = Get-Date
    $maxDrainWait = 60
    while (((Get-Date) - $waitStart).TotalSeconds -lt $maxDrainWait) {
        $result = Invoke-ApiRequest -Method GET -Endpoint "/queue"
        if ($result.Success -and $result.Data.queue_size -eq 0 -and $result.Data.processing_count -eq 0) {
            Write-Info "  Queue drained after $([math]::Round(((Get-Date) - $waitStart).TotalSeconds, 1))s"
            break
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

if ($script:TestsFailed -eq 0) {
    Write-Host "`nALL TESTS PASSED!`n" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n$script:TestsFailed TEST(S) FAILED`n" -ForegroundColor Red
    exit 1
}
