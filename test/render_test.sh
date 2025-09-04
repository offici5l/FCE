#!/bin/bash

ROM_URL="https://ultimateota.d.miui.com/OS2.0.201.0.VNTEUXM/moon_eea_global-ota_full-OS2.0.201.0.VNTEUXM-user-15.0-5e31983d6e.zip?t=1755293681&s=219e32da0eb22c71926089713a"
FILE_TO_EXTRACT="boot"
SERVICE_URL="https://fce-service.onrender.com"

START_TIME=$(date +%s)

echo "Starting extraction task for '$FILE_TO_EXTRACT'..."
RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" -d "{\"url\":\"$ROM_URL\", \"file\":\"$FILE_TO_EXTRACT\"}" "$SERVICE_URL/extract")

if ! echo "$RESPONSE" | grep -q "task_id"; then
    echo "Error: Failed to start task."
    echo "Server Response: $RESPONSE"
    exit 1
fi

TASK_ID=$(echo "$RESPONSE" | sed -e 's/.*"task_id":"\([^"']\*\)".*/\1/')
echo "Task started with ID: $TASK_ID"

echo "---"
echo "Streaming live log..."
curl -N "$SERVICE_URL/status/$TASK_ID"
echo "
---"

read -p "Press Enter to download the output file..."
echo "Downloading file..."
curl --progress-bar -o "${FILE_TO_EXTRACT}.zip" "$SERVICE_URL/download/$TASK_ID"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "
Download complete. File saved as ${FILE_TO_EXTRACT}.zip"
echo "----------------------------------"
echo "Total operation time: $DURATION seconds."
