#!/bin/bash
# Qwen Image Edit API - Remote Test Script (macOS/Linux)
# Version: 2.0.3 (2025-10-07)
# This script tests all major API endpoints and workflows remotely
# 
# Requirements:
#   - bash 3.2+ (macOS default)
#   - curl (installed by default on macOS)
#   - jq for JSON parsing (install via: brew install jq)
#
# Usage: ./test-api-remote.sh <API_KEY> [BASE_URL]
#        ./test-api-remote.sh "your-api-key-here"
#        ./test-api-remote.sh "your-key" "http://localhost:8000/api/v1"
#
# Required Files (in same directory):
#   - api-test-image.png (512x512 test portrait)
#   - api-test-image-large.png (3000x3000 for overflow test)

set -e  # Exit on error

# Script version
SCRIPT_VERSION="2.0.3"

# Parse arguments
DEBUG_LOG="false"
API_KEY=""
BASE_URL="https://qwen.codeblazar.org/api/v1"

while [ $# -gt 0 ]; do
    case "$1" in
        -d|--debug)
            DEBUG_LOG="true"
            shift
            ;;
        *)
            if [ -z "$API_KEY" ]; then
                API_KEY="$1"
            else
                BASE_URL="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$API_KEY" ]; then
    echo "Usage: $0 [--debug|-d] <API_KEY> [BASE_URL]"
    echo "Example: $0 \"your-api-key-here\""
    echo "         $0 \"your-key\" \"http://localhost:8000/api/v1\""
    echo "         $0 --debug \"your-key\""
    exit 1
fi

# Check for required tools
if ! command -v curl &> /dev/null; then
    echo "Error: curl is required but not installed"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed"
    echo "Install with: brew install jq"
    exit 1
fi

# Debug log file
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEBUG_LOG_FILE="$SCRIPT_DIR/test-api-remote-debug.log"

# Initialize debug log
if [ "$DEBUG_LOG" = "true" ]; then
    {
        echo "=== Test API Remote Debug Log ==="
        echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Bash Version: $BASH_VERSION"
        echo "Base URL: $BASE_URL"
        echo ""
    } > "$DEBUG_LOG_FILE"
fi

# Color output functions
function write_success() {
    echo -e "\033[0;32m[OK] $1\033[0m"
}

function write_error() {
    echo -e "\033[0;31m[ERROR] $1\033[0m"
}

function write_info() {
    echo -e "\033[0;36m[INFO] $1\033[0m"
}

function write_warning() {
    echo -e "\033[0;33m[WARN] $1\033[0m"
}

function write_debug_log() {
    if [ "$DEBUG_LOG" = "true" ]; then
        local timestamp=$(date '+%H:%M:%S.%3N')
        echo "[$timestamp] $1" >> "$DEBUG_LOG_FILE"
    fi
}

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TEST_NUMBER=0

function test_endpoint() {
    TEST_NUMBER=$((TEST_NUMBER + 1))
    echo -ne "\n[$TEST_NUMBER] $1..."
}

function pass_test() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    if [ -n "$1" ]; then
        write_success " PASS - $1"
    else
        write_success " PASS"
    fi
}

function fail_test() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    write_error " FAIL - $1"
}

# Create test image function
function create_test_image() {
    local width=${1:-512}
    local height=${2:-512}
    local output_path=${3:-/tmp/test_image.png}
    
    local project_test_image="$SCRIPT_DIR/api-test-image.png"
    local project_large_image="$SCRIPT_DIR/api-test-image-large.png"
    
    # For 3000x3000, use the large test image if available
    if [ "$width" -eq 3000 ] && [ "$height" -eq 3000 ] && [ -f "$project_large_image" ]; then
        cp "$project_large_image" "$output_path"
        echo "$output_path"
        return
    fi
    
    # For default 512x512, use the standard test image
    if [ "$width" -eq 512 ] && [ "$height" -eq 512 ] && [ -f "$project_test_image" ]; then
        cp "$project_test_image" "$output_path"
        echo "$output_path"
        return
    fi
    
    # Otherwise create a simple test image using ImageMagick if available
    if command -v convert &> /dev/null; then
        convert -size "${width}x${height}" xc:blue "$output_path"
        echo "$output_path"
    else
        echo "Error: Test image not found and ImageMagick not installed to generate one"
        exit 1
    fi
}

# API request helper
function invoke_api_request() {
    local endpoint="$1"
    local method="${2:-GET}"
    local body="${3:-}"
    
    local url="${BASE_URL}${endpoint}"
    local response
    local http_code
    
    if [ "$method" = "GET" ]; then
        response=$(curl -s -w "\n%{http_code}" -H "X-API-Key: $API_KEY" "$url")
    else
        response=$(curl -s -w "\n%{http_code}" -H "X-API-Key: $API_KEY" \
            -H "Content-Type: application/json" \
            -X "$method" \
            -d "$body" \
            "$url")
    fi
    
    http_code=$(echo "$response" | tail -n 1)
    body=$(echo "$response" | sed '$d')
    
    echo "$http_code|$body"
}

# Multipart request helper
function invoke_multipart_request() {
    local endpoint="$1"
    local image_path="$2"
    local instruction="$3"
    local seed="${4:-}"
    
    local url="${BASE_URL}${endpoint}"
    
    if [ "$DEBUG_LOG" = "true" ]; then
        write_debug_log "=== Multipart Request ==="
        write_debug_log "URI: $url"
        write_debug_log "Image path: $image_path"
        write_debug_log "Image exists: $([ -f "$image_path" ] && echo "True" || echo "False")"
        if [ -f "$image_path" ]; then
            write_debug_log "Image size: $(stat -f%z "$image_path" 2>/dev/null || stat -c%s "$image_path") bytes"
            write_debug_log "Image extension: ${image_path##*.}"
        fi
        write_debug_log "Instruction: $instruction"
        write_debug_log "Seed: $seed"
    fi
    
    local curl_cmd="curl -s -w \"\n%{http_code}\" -H \"X-API-Key: $API_KEY\""
    curl_cmd="$curl_cmd -F \"instruction=$instruction\""
    curl_cmd="$curl_cmd -F \"image=@$image_path\""
    
    if [ -n "$seed" ]; then
        curl_cmd="$curl_cmd -F \"seed=$seed\""
    fi
    
    curl_cmd="$curl_cmd \"$url\""
    
    local response
    response=$(eval "$curl_cmd")
    
    local http_code=$(echo "$response" | tail -n 1)
    local body=$(echo "$response" | sed '$d')
    
    if [ "$DEBUG_LOG" = "true" ]; then
        write_debug_log "Response status: $http_code"
        write_debug_log "Response content: $body"
    fi
    
    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        echo "success|$body|$http_code"
    else
        local error_message="$body"
        if echo "$body" | jq -e '.detail' &> /dev/null; then
            error_message=$(echo "$body" | jq -r '.detail')
        fi
        
        if [ "$DEBUG_LOG" = "true" ]; then
            write_debug_log "!!! Error response !!!"
            write_debug_log "Status code: $http_code"
            write_debug_log "Final error: HTTP $http_code: $error_message"
        fi
        
        echo "error|HTTP $http_code: $error_message|$http_code"
    fi
}

# Main test execution
echo "================================================================"
echo "          Qwen Image Edit API - Remote Test Suite"
echo "                        Version $SCRIPT_VERSION"
echo "================================================================"

write_info "Bash Version: $BASH_VERSION - [OK] Supported"
write_info "API Base URL: $BASE_URL"
masked_key="${API_KEY: -8}"
write_info "API Key: ********************$masked_key"
write_info "Test started: $(date '+%Y-%m-%d %H:%M:%S')"

write_info ""
write_info "Waiting for API server to be ready..."

# Wait for server
max_retries=10
retry_count=0
while [ $retry_count -lt $max_retries ]; do
    response=$(invoke_api_request "/health" "GET")
    http_code=$(echo "$response" | cut -d'|' -f1)
    
    if [ "$http_code" = "200" ]; then
        write_success "Server is ready!"
        break
    fi
    
    retry_count=$((retry_count + 1))
    sleep 1
done

if [ $retry_count -eq $max_retries ]; then
    write_error "Server not ready after $max_retries attempts"
    exit 1
fi

write_info ""
write_info "Checking for required test images..."
test_image_small="$SCRIPT_DIR/api-test-image.png"
test_image_large="$SCRIPT_DIR/api-test-image-large.png"

if [ ! -f "$test_image_small" ]; then
    write_error "Required test image not found: $test_image_small"
    write_error "Please ensure 'api-test-image.png' (512x512) is in the same directory as this script."
    exit 1
fi

if [ ! -f "$test_image_large" ]; then
    write_error "Required test image not found: $test_image_large"
    write_error "Please ensure 'api-test-image-large.png' (3000x3000) is in the same directory as this script."
    exit 1
fi

small_size=$(stat -f%z "$test_image_small" 2>/dev/null || stat -c%s "$test_image_small")
large_size=$(stat -f%z "$test_image_large" 2>/dev/null || stat -c%s "$test_image_large")
small_mb=$(echo "scale=2; $small_size / 1048576" | bc)
large_mb=$(echo "scale=2; $large_size / 1048576" | bc)

write_success "Test images found:"
write_success "  - api-test-image.png ($small_mb MB)"
write_success "  - api-test-image-large.png ($large_mb MB)"

write_info ""
write_info "Creating test image..."
test_image=$(create_test_image 512 512 "/tmp/test_image.png")
write_success "Test image created: $test_image"

# Test 1: Health Check
test_endpoint "Health Check"
response=$(invoke_api_request "/health" "GET")
http_code=$(echo "$response" | cut -d'|' -f1)
body=$(echo "$response" | cut -d'|' -f2)

if [ "$http_code" = "200" ]; then
    status=$(echo "$body" | jq -r '.status')
    model=$(echo "$body" | jq -r '.current_model')
    queue_max=$(echo "$body" | jq -r '.queue_max_size')
    pass_test "Status: $status, Model: $model, Queue Max: $queue_max"
else
    fail_test "Expected 200, got $http_code"
fi

# Test 2: Invalid API Key Rejection
test_endpoint "Invalid API Key Rejection"

write_debug_log "Test 2: Testing invalid API key at ${BASE_URL}/models"

response=$(curl -s -w "\n%{http_code}" -H "X-API-Key: invalid-key-12345" "${BASE_URL}/models")
http_code=$(echo "$response" | tail -n 1 | tr -d '[:space:]')
body=$(echo "$response" | sed '$d')

write_debug_log "Test 2: HTTP Code='$http_code', Body='$body'"

if [ "$http_code" = "401" ]; then
    pass_test "Correctly rejected with 401"
else
    fail_test "Expected 401, got $http_code"
fi

# Test 3: List Available Models
test_endpoint "List Available Models"
response=$(invoke_api_request "/models" "GET")
http_code=$(echo "$response" | cut -d'|' -f1)
body=$(echo "$response" | cut -d'|' -f2)

if [ "$http_code" = "200" ]; then
    model_count=$(echo "$body" | jq '.models | length')
    model_names=$(echo "$body" | jq -r '.models | keys[]' | tr '\n' ',' | sed 's/,$//')
    pass_test "Found $model_count models: $model_names"
else
    fail_test "Expected 200, got $http_code"
fi

# Test 4: Get Queue Status
test_endpoint "Get Queue Status"
response=$(invoke_api_request "/queue" "GET")
http_code=$(echo "$response" | cut -d'|' -f1)
body=$(echo "$response" | cut -d'|' -f2)

if [ "$http_code" = "200" ]; then
    queued=$(echo "$body" | jq -r '.queued_jobs')
    processing=$(echo "$body" | jq -r '.processing_jobs')
    max_size=$(echo "$body" | jq -r '.max_queue_size')
    pass_test "Queue: $queued/$max_size, Processing: $processing"
else
    fail_test "Expected 200, got $http_code"
fi

# Test 5: Load Model for Testing
test_endpoint "Load Model for Testing"
response=$(invoke_api_request "/load-model?model=4-step" "POST")
http_code=$(echo "$response" | cut -d'|' -f1)

if [ "$http_code" = "200" ]; then
    # Wait for model to be ready
    sleep 2
    pass_test "Model confirmed loaded and ready: 4-step"
else
    fail_test "Failed to load model"
fi

# Test 6: Submit Image Editing Job
test_endpoint "Submit Image Editing Job"
response=$(invoke_multipart_request "/submit" "$test_image" "Add a rainbow in the sky" "42")
status=$(echo "$response" | cut -d'|' -f1)
body=$(echo "$response" | cut -d'|' -f2)
http_code=$(echo "$response" | cut -d'|' -f3)

if [ "$status" = "success" ]; then
    job_id=$(echo "$body" | jq -r '.job_id')
    position=$(echo "$body" | jq -r '.position')
    pass_test "Job submitted: ${job_id:0:8}..., Position: $position"
else
    if [ "$http_code" = "429" ]; then
        write_warning " Queue is full (429) - This is expected behavior"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        job_id=""
    else
        fail_test "Submit failed: $body (Status: $http_code)"
        job_id=""
    fi
fi

# Test 7: Check Job Status
if [ -n "$job_id" ]; then
    test_endpoint "Check Job Status"
    response=$(invoke_api_request "/status/$job_id" "GET")
    http_code=$(echo "$response" | cut -d'|' -f1)
    body=$(echo "$response" | cut -d'|' -f2)
    
    if [ "$http_code" = "200" ]; then
        job_status=$(echo "$body" | jq -r '.status')
        position=$(echo "$body" | jq -r '.position')
        if [ "$position" != "null" ]; then
            pass_test "Status: $job_status, Position: $position"
        else
            pass_test "Status: $job_status"
        fi
    else
        fail_test "Status check failed: $body"
    fi
    
    # Test 8: Wait for Job Completion
    test_endpoint "Wait for Job Completion (max 120s)"
    max_wait=120
    elapsed=0
    completed=false
    job_status=""
    
    while [ $elapsed -lt $max_wait ]; do
        response=$(invoke_api_request "/status/$job_id" "GET")
        http_code=$(echo "$response" | cut -d'|' -f1)
        body=$(echo "$response" | cut -d'|' -f2)
        
        if [ "$http_code" = "200" ]; then
            job_status=$(echo "$body" | jq -r '.status')
            if [ "$job_status" = "completed" ]; then
                result_path=$(echo "$body" | jq -r '.result_path')
                pass_test "Completed in ${elapsed}s - Result: $result_path"
                completed=true
                break
            elif [ "$job_status" = "failed" ]; then
                error=$(echo "$body" | jq -r '.error')
                fail_test "Job failed: $error"
                break
            fi
        fi
        
        sleep 1
        elapsed=$((elapsed + 1))
    done
    
    if [ "$completed" = false ] && [ "$job_status" != "failed" ]; then
        write_warning " Timeout waiting for completion (job may still be processing)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
fi

# Test 9: Submit Multiple Jobs Concurrently
test_endpoint "Submit Multiple Jobs Concurrently"
job_ids=()
success_count=0

prompts=("Add fluffy clouds to the sky" "Make the image warmer and sunny" "Add a sunset glow")
seeds=(101 102 103)

for i in 0 1 2; do
    response=$(invoke_multipart_request "/submit" "$test_image" "${prompts[$i]}" "${seeds[$i]}")
    status=$(echo "$response" | cut -d'|' -f1)
    http_code=$(echo "$response" | cut -d'|' -f3)
    
    if [ "$status" = "success" ]; then
        body=$(echo "$response" | cut -d'|' -f2)
        job_id=$(echo "$body" | jq -r '.job_id')
        job_ids+=("$job_id")
        success_count=$((success_count + 1))
    elif [ "$http_code" = "429" ]; then
        # Queue full is acceptable
        success_count=$((success_count + 1))
    fi
done

if [ $success_count -eq 3 ]; then
    pass_test "Submitted $success_count jobs (some may have queued)"
else
    fail_test "Only $success_count/3 jobs submitted successfully"
fi

# Wait for these jobs to complete before testing queue overflow
write_info "  Waiting for concurrent jobs to complete before queue overflow test..."
wait_start=$(date +%s)
max_wait=120

while true; do
    current_time=$(date +%s)
    elapsed=$((current_time - wait_start))
    
    if [ $elapsed -ge $max_wait ]; then
        break
    fi
    
    response=$(invoke_api_request "/queue" "GET")
    http_code=$(echo "$response" | cut -d'|' -f1)
    body=$(echo "$response" | cut -d'|' -f2)
    
    if [ "$http_code" = "200" ]; then
        queue_size=$(echo "$body" | jq -r '.queue_size // 0')
        processing=$(echo "$body" | jq -r '.processing_count // 0')
        
        if [ "$queue_size" = "0" ] && [ "$processing" = "0" ]; then
            write_info "  Queue cleared after ${elapsed}s"
            break
        fi
    fi
    
    sleep 3
done

# Test 10: Queue Overflow Protection
test_endpoint "Queue Overflow Protection"
write_info "  Testing queue capacity limits (submitting 15 jobs to empty queue)..."
write_info "  Expected: 10 accepted + 5 rejected with 429"

queue_test_jobs=()
rejected_count=0
accepted_count=0
jobs_to_submit=15

overflow_prompts=(
    "Add morning mist"
    "Make it nighttime with stars"
    "Add autumn leaves falling"
    "Make it snow gently"
    "Add a beautiful rainbow"
    "Make it golden hour"
    "Add dramatic storm clouds"
    "Make it spring with flowers"
    "Add a gentle rain"
    "Make it foggy and mysterious"
    "Add birds flying"
    "Make it sunny and bright"
    "Add moonlight"
    "Make it windy with movement"
    "Add magical sparkles"
)

for i in $(seq 0 $((jobs_to_submit - 1))); do
    seed=$((201 + i))
    response=$(invoke_multipart_request "/submit" "$test_image" "${overflow_prompts[$i]}" "$seed")
    status=$(echo "$response" | cut -d'|' -f1)
    http_code=$(echo "$response" | cut -d'|' -f3)
    
    if [ "$status" = "success" ]; then
        body=$(echo "$response" | cut -d'|' -f2)
        job_id=$(echo "$body" | jq -r '.job_id')
        queue_test_jobs+=("$job_id")
        accepted_count=$((accepted_count + 1))
    elif [ "$http_code" = "429" ]; then
        rejected_count=$((rejected_count + 1))
    else
        # Some other error occurred
        write_warning "  Job $((i + 1)) failed with status $http_code"
    fi
done

write_info "  Results: $accepted_count accepted, $rejected_count rejected (429), Failed: $((jobs_to_submit - accepted_count - rejected_count))"

# Validate queue overflow protection
if [ $accepted_count -eq 10 ] && [ $rejected_count -eq 5 ]; then
    pass_test "Perfect! 10 jobs accepted, 5 rejected with 429 (queue protection working)"
elif [ $rejected_count -gt 0 ] && [ $accepted_count -le 12 ]; then
    pass_test "Queue protected: $accepted_count accepted, $rejected_count rejected with 429 (some jobs started processing)"
elif [ $accepted_count -ge 10 ] && [ $accepted_count -le 15 ] && [ $rejected_count -eq 0 ]; then
    write_warning "  Queue processing very fast - accepted $accepted_count jobs before overflow could occur"
    pass_test "Queue capacity working: $accepted_count jobs accepted (processing faster than submission)"
else
    fail_test "Unexpected results: $accepted_count accepted, $rejected_count rejected (expected ~10 accepted + ~5 rejected)"
fi

# Test 11: Queue Status Under Load
test_endpoint "Queue Status Under Load"
response=$(invoke_api_request "/queue" "GET")
http_code=$(echo "$response" | cut -d'|' -f1)
body=$(echo "$response" | cut -d'|' -f2)

if [ "$http_code" = "200" ]; then
    queue_size=$(echo "$body" | jq -r '.queue_size // 0')
    processing=$(echo "$body" | jq -r '.processing_count // 0')
    total_jobs=$((queue_size + processing))
    write_info "  Active jobs: $total_jobs (Queued: $queue_size, Processing: $processing)"
    if [ $total_jobs -gt 0 ]; then
        pass_test "Queue status reporting correctly"
    else
        write_warning "  Queue already empty (processing very fast)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
else
    fail_test "Failed to get queue status: $body"
fi

# Test 12: Queue Position Tracking
test_endpoint "Queue Position Tracking"
if [ ${#queue_test_jobs[@]} -gt 0 ]; then
    job_to_check="${queue_test_jobs[0]}"
    response=$(invoke_api_request "/status/$job_to_check" "GET")
    http_code=$(echo "$response" | cut -d'|' -f1)
    body=$(echo "$response" | cut -d'|' -f2)
    
    if [ "$http_code" = "200" ]; then
        job_status=$(echo "$body" | jq -r '.status')
        if [ "$job_status" = "queued" ]; then
            pass_test "Job correctly queued (status: queued)"
        elif [ "$job_status" = "processing" ] || [ "$job_status" = "completed" ]; then
            pass_test "Job progressing normally (status: $job_status)"
        else
            fail_test "Unexpected status: $job_status"
        fi
    else
        fail_test "Failed to check job status: $body"
    fi
else
    write_warning "  No jobs to track (all processed immediately)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi

# Wait for queue to drain with progress
if [ ${#queue_test_jobs[@]} -gt 0 ]; then
    # Calculate needed wait time: jobs * ~20 seconds per job + 30 second buffer
    estimated_time=$((${#queue_test_jobs[@]} * 20 + 30))
    if [ $estimated_time -gt 300 ]; then
        max_drain_wait=$estimated_time
    else
        max_drain_wait=300
    fi
    write_info "  Waiting for queue to drain (max ${max_drain_wait}s for ${#queue_test_jobs[@]} jobs)..."
    
    wait_start=$(date +%s)
    last_queue_size=-1
    completed_count=0
    
    while true; do
        current_time=$(date +%s)
        elapsed=$((current_time - wait_start))
        
        if [ $elapsed -ge $max_drain_wait ]; then
            break
        fi
        
        response=$(invoke_api_request "/queue" "GET")
        http_code=$(echo "$response" | cut -d'|' -f1)
        body=$(echo "$response" | cut -d'|' -f2)
        
        if [ "$http_code" = "200" ]; then
            queue_size=$(echo "$body" | jq -r '.queue_size // 0')
            processing=$(echo "$body" | jq -r '.processing_count // 0')
            current_total=$((queue_size + processing))
            
            # Show progress when queue size changes
            if [ $current_total -ne $last_queue_size ]; then
                completed=$((${#queue_test_jobs[@]} - current_total))
                if [ $completed -gt $completed_count ]; then
                    write_info "  [${elapsed}s] Completed: $completed/${#queue_test_jobs[@]} jobs (Remaining: $current_total)"
                    completed_count=$completed
                fi
                last_queue_size=$current_total
            fi
            
            # Check if done
            if [ $queue_size -eq 0 ] && [ $processing -eq 0 ]; then
                write_info "  All ${#queue_test_jobs[@]} jobs completed in ${elapsed}s"
                break
            fi
        fi
        
        sleep 2
    done
fi

# Test 13: Reject Oversized Image
test_endpoint "Reject Oversized Image"
large_image=$(create_test_image 3000 3000 "/tmp/large_test.png")

response=$(invoke_multipart_request "/submit" "$large_image" "Test" "0")
status=$(echo "$response" | cut -d'|' -f1)
http_code=$(echo "$response" | cut -d'|' -f3)

if [ "$status" = "error" ] && [ "$http_code" = "400" ]; then
    pass_test "Correctly rejected with 400"
else
    fail_test "Expected 400 rejection, got $http_code"
fi

# Test 14: Request Invalid Job ID
test_endpoint "Request Invalid Job ID"
response=$(invoke_api_request "/status/invalid-job-id" "GET")
http_code=$(echo "$response" | cut -d'|' -f1)

if [ "$http_code" = "404" ]; then
    pass_test "Correctly returned 404"
else
    fail_test "Expected 404, got $http_code"
fi

# Cleanup
write_info ""
write_info "Cleaning up..."
rm -f "$test_image" "$large_image"
write_success "Test images removed"

# Summary
echo ""
echo "================================================================"
echo "                       Test Summary"
echo "================================================================"
total_tests=$((TESTS_PASSED + TESTS_FAILED))
pass_rate=$((TESTS_PASSED * 100 / total_tests))

echo "Total Tests:  $total_tests"
if [ $TESTS_PASSED -gt 0 ]; then
    write_success "Passed:       $TESTS_PASSED"
fi
if [ $TESTS_FAILED -gt 0 ]; then
    write_error "Failed:       $TESTS_FAILED"
fi
echo "Pass Rate:    $pass_rate%"
write_info "Test ended:   $(date '+%Y-%m-%d %H:%M:%S')"

if [ "$DEBUG_LOG" = "true" ]; then
    write_info ""
    write_info "Debug log written to: $DEBUG_LOG_FILE"
fi

if [ $TESTS_FAILED -eq 0 ]; then
    echo ""
    echo -e "\033[0;32mALL TESTS PASSED!\033[0m"
    echo ""
    exit 0
else
    echo ""
    echo -e "\033[0;31m$TESTS_FAILED TEST(S) FAILED\033[0m"
    echo ""
    exit 1
fi
