#!/bin/bash
set -euo pipefail

# --- Configuration ---
PROXY_URL="https://fce-proxy.vercel.app/api/trigger"
REPO_URL="https://github.com/offici5l/FCE"

# --- Helper Functions ---

# Display usage information
show_usage() {
    echo "Usage: $0 <rom_url> <file_to_extract>"
    echo "  <rom_url>          : URL of the ROM zip file."
    echo "  <file_to_extract>  : Name of the image to extract (e.g., boot, vendor_boot)."
}

# Check for required dependencies
check_deps() {
    for cmd in curl jq; do
        if ! command -v "$cmd" &> /dev/null;
        then
            echo "Error: Required command '$cmd' is not installed." >&2
            exit 1
        fi
    done
}

# Call the proxy API
call_proxy() {
    curl -s -X POST -H "Content-Type: application/json" -d "$1" "$PROXY_URL"
}

# Find the workflow run ID for a given unique ID
find_run_id() {
    local unique_id="$1"
    local run_id=""
    local attempts=0
    local delay=10
    echo "🔎 Waiting for workflow to start..."
    while [ -z "$run_id" ] && [ $attempts -lt 60 ]; do
        attempts=$((attempts+1))
        echo -ne "\r   Attempt $attempts/60, waiting ${delay}s... "
        sleep $delay
        if [ $delay -lt 15 ]; then
            delay=$((delay+1))
        fi

        local response
        response=$(call_proxy '{"action": "get_runs"}')
        for id in $(echo "$response" | jq -r '.workflow_runs[]?.id'); do
            local jobs_response
            jobs_response=$(call_proxy "{\"action\": \"get_jobs\", \"run_id\": $id}")
            if echo "$jobs_response" | jq -e --arg UNIQUE_ID "$unique_id" '.jobs[] | select(.name == $UNIQUE_ID)' > /dev/null; then
                run_id=$id
                break
            fi
        done
    done
    echo
    echo "$run_id"
}

# Watch the workflow until it completes
watch_workflow() {
    local run_id="$1"
    local status="in_progress"
    local conclusion=""
    local delay=10

    echo "👀 Watching workflow progress..."
    while [ "$status" != "completed" ]; do
        sleep $delay
        if [ $delay -lt 15 ]; then
            delay=$((delay+1))
        fi

        local response
        response=$(call_proxy "{\"action\": \"get_run_details\", \"run_id\": $run_id}")
        status=$(echo "$response" | jq -r '.status')
        conclusion=$(echo "$response" | jq -r '.conclusion')
        echo -ne "\r   Workflow status: $status... "
    done
    echo
    echo "   Workflow finished with conclusion: $conclusion"

    [ "$conclusion" == "success" ]
}

# Wait for the output file to become available
wait_for_output() {
    local output_url="$1"
    local delay=10
    local attempts=0
    echo "⏳ Checking if output is available..."
    while [ $attempts -lt 90 ]; do # Wait for up to ~15 minutes
        attempts=$((attempts+1))
        local http_status
        http_status=$(curl -s -o /dev/null -w "%{{http_code}}" -IL "$output_url")
        if [ "$http_status" -eq 200 ]; then
            echo
            return 0
        fi
        echo -ne "\r   ... waiting for output (attempt $attempts, delay ${delay}s)"
        sleep $delay
        if [ $delay -lt 15 ]; then
            delay=$((delay+1))
        fi
    done
    echo
    return 1
}

# --- Main Logic ---
main() {
    check_deps

    if [ "$#" -ne 2 ]; then
        show_usage
        exit 1
    fi

    local url_input="$1"
    local file_input="$2"

    local filename
    filename=$(basename "$url_input" | cut -d'?' -f1 | sed 's/\.zip$//')
    local unique_id="${file_input}_${filename}"
    local output_url="${REPO_URL}/releases/download/${unique_id}/${file_input}.zip"

    echo "🔎 Checking for existing output..."
    local http_status
    http_status=$(curl -s -o /dev/null -w "%{{http_code}}" -IL "$output_url")

    if [ "$http_status" -eq 200 ]; then
        echo "✅ Output already exists and is available here:"
        echo "  $output_url"
        exit 0
    fi

    echo "ℹ️ No existing output found. Starting new workflow..."
    local response
    response=$(call_proxy "{{\"action\": \"trigger\", \"url\": \"$url_input\", \"file\": \"$file_input\", \"unique_id\": \"$unique_id\"}}")

    local ok
    ok=$(echo "$response" | jq -r '.ok')
    if [ "$ok" != "true" ]; then
        echo "❌ Failed to trigger workflow"
        local error
        error=$(echo "$response" | jq -r '.error // empty')
        if [ -n "$error" ]; then
            echo "   Error: $error"
        fi
        exit 1
    fi
    echo "✅ Workflow triggered successfully (ID: $unique_id)"

    local run_id
    run_id=$(find_run_id "$unique_id")
    if [ -z "$run_id" ]; then
        echo "❌ No workflow run detected for $unique_id after 10 minutes."
        exit 1
    fi
    echo "✅ Workflow run detected: ID = $run_id"

    if ! watch_workflow "$run_id"; then
        echo "❌ Workflow failed. See details at ${REPO_URL}/actions/runs/${run_id}"
        exit 1
    fi

    if ! wait_for_output "$output_url"; then
        echo "❌ Output was not ready after waiting. Try again later."
        exit 1
    fi

    echo "✅ Output is ready :"
    echo "  $output_url"
}

# --- Run ---
main "$@"
