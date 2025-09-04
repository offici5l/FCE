#!/bin/bash
set -e

ROM_URL='https://ultimateota.d.miui.com/OS2.0.201.0.VNTEUXM/moon_eea_global-ota_full-OS2.0.201.0.VNTEUXM-user-15.0-5e31983d6e.zip?t=1755293681&s=219e32da0eb22c71926089713a'
FILE_TO_EXTRACT='boot'
SERVICE_URL='https://fce-service.onrender.com'

START_TIME=$(date +%s)

echo "Starting task..."

JSON_PAYLOAD=$(printf '{"url":"%s", "file":"%s"}' "$ROM_URL" "$FILE_TO_EXTRACT")

RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" -d "$JSON_PAYLOAD" "$SERVICE_URL/extract")

TASK_ID=$(echo "$RESPONSE" | sed -e 's/.*"task_id":"\([^"]*\)".*/\1/')

if [ -z "$TASK_ID" ] || [ "$TASK_ID" = "$RESPONSE" ]; then
    echo "Error: Failed to get task ID."
    echo "Server Response: $RESPONSE"
    exit 1
fi
echo "Task ID: $TASK_ID"

echo "---"
echo "Streaming log..."
curl -N "$SERVICE_URL/status/$TASK_ID"
echo "---"

read -p "Press Enter to download..."
echo "Downloading..."
curl --progress-bar -o "${FILE_TO_EXTRACT}.zip" "$SERVICE_URL/download/$TASK_ID"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "
Download complete. File saved as ${FILE_TO_EXTRACT}.zip"
echo "Total time: $DURATION seconds."
