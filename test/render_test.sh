#!/bin/bash

# --- Configuration ---
# You can change these values to test different files.
ROM_URL="https://ultimateota.d.miui.com/OS2.0.201.0.VNTEUXM/moon_eea_global-ota_full-OS2.0.201.0.VNTEUXM-user-15.0-5e31983d6e.zip?t=1755293681&s=219e32da0eb22c71926089713a"
FILE_TO_EXTRACT="boot"
SERVICE_URL="https://fce-service.onrender.com"

# --- Step 1: Start Task & Get ID ---
echo "Starting extraction task for '$FILE_TO_EXTRACT'..."
RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" -d "{\"url\":\"$ROM_URL\", \"file\":\"$FILE_TO_EXTRACT\"}" "$SERVICE_URL/extract")

# Check if response is valid JSON with task_id
if ! echo "$RESPONSE" | grep -q "task_id"; then
    echo "Error: Failed to start task. The server might be down or running an old version."
    echo "Server Response: $RESPONSE"
    exit 1
fi

# Extract task_id using standard shell tools
TASK_ID=$(echo "$RESPONSE" | sed -e 's/.*"task_id":"\([^"]*\)".*/\1/')
echo "Task started successfully with ID: $TASK_ID"


# --- Step 2: Stream Status ---
echo "---"
echo "Streaming live log. Press Ctrl+C when the process is finished."
echo "---"
curl -N "$SERVICE_URL/status/$TASK_ID"
echo "
---"


# --- Step 3: Download File ---
read -p "Press Enter to download the output file..."
echo "Downloading file..."
curl --progress-bar -o "${FILE_TO_EXTRACT}.zip" "$SERVICE_URL/download/$TASK_ID"

echo "
Download complete. File saved as ${FILE_TO_EXTRACT}.zip"