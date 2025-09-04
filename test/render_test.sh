#!/bin/bash
set -e

ROM_URL="https://ultimateota.d.miui.com/OS2.0.201.0.VNTEUXM/moon_eea_global-ota_full-OS2.0.201.0.VNTEUXM-user-15.0-5e31983d6e.zip?t=1755293681&s=219e32da0eb22c71926089713a"
FILE_TO_EXTRACT="boot"
SERVICE_URL="https://fce-service.onrender.com"

START_TIME=$(date +%s)

echo "Starting extraction task for '$FILE_TO_EXTRACT'..."

JSON_PAYLOAD=$(printf '{"url":"%s", "file":"%s"}' "$ROM_URL" "$FILE_TO_EXTRACT")

# Make a single, direct call to the /extract endpoint
# The server will respond with the file or a JSON error
RESPONSE_HEADERS=$(curl -s -X POST -H "Content-Type: application/json" -d "$JSON_PAYLOAD" -D - -o "${FILE_TO_EXTRACT}.zip" "$SERVICE_URL/extract")

# Check if the response was a file download or a JSON error
if echo "$RESPONSE_HEADERS" | grep -q "Content-Type: application/zip"; then
    echo "
Download complete. File saved as ${FILE_TO_EXTRACT}.zip"
else
    # If not a zip, it's likely a JSON error. Read the saved file content.
    ERROR_CONTENT=$(cat "${FILE_TO_EXTRACT}.zip")
    echo "
Error: Server did not return a zip file."
    echo "Server Response: $ERROR_CONTENT"
    rm -f "${FILE_TO_EXTRACT}.zip" # Clean up the non-zip file
    exit 1
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "----------------------------------"
echo "Total operation time: $DURATION seconds."
