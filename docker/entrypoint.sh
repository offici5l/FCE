#!/bin/bash
set -euo pipefail

mkdir -p /workspace/output

# Check for required tools
for tool in aria2c 7z python3 zip; do
  if ! command -v "$tool" &> /dev/null; then
    echo "ERROR: Required tool '$tool' is not installed." >&2
    exit 1
  fi
done

# --- Input Validation ---
if [ -z "${1-}" ]; then
  echo "ERROR: ROM URL not provided." >&2
  echo "Usage: $0 <URL> <FILE_TO_EXTRACT>" >&2
  exit 1
fi

if [ -z "${2-}" ]; then
  echo "ERROR: File to extract not provided." >&2
  echo "Usage: $0 <URL> <FILE_TO_EXTRACT>" >&2
  exit 1
fi

URL="$1"
FILE_TO_EXTRACT="$2"

# --- URL Transformation ---
echo "--> Transforming URL..."
MIUI_DOMAINS=(
  "ultimateota.d.miui.com"
  "superota.d.miui.com"
  "bigota.d.miui.com"
  "cdnorg.d.miui.com"
  "bn.d.miui.com"
  "hugeota.d.miui.com"
  "cdn-ota.azureedge.net"
  "airtel.bigota.d.miui.com"
)
REPLACEMENT_DOMAIN="bkt-sgp-miui-ota-update-alisgp.oss-ap-southeast-1.aliyuncs.com"

for domain in "${MIUI_DOMAINS[@]}"; do
  if [[ "$URL" == *"$domain"* ]]; then
    URL="${URL/$domain/$REPLACEMENT_DOMAIN}"
    break
  fi
done

if [[ ! "$URL" =~ \.zip(\?.*)?$ ]]; then
    echo "ERROR: Only .zip URLs are supported."
    exit 1
fi

echo "--> Final download URL: $URL"


# --- Main Logic ---
cd /workspace
echo "--> Downloading ROM from $URL"
if ! aria2c -x16 -s16 -o rom.zip "$URL"; then
  echo "ERROR: Failed to download ROM." >&2
  exit 1
fi

echo "--> Extracting ROM..."
mkdir -p extracted
if ! 7z x rom.zip -oextracted >/dev/null; then
    echo "ERROR: Failed to extract ROM archive." >&2
    exit 1
fi
cd extracted

# --- Output Handling ---
mkdir -p ../output

OUTPUT_IMG="../output/${FILE_TO_EXTRACT}.img"
OUTPUT_ZIP="../output/${FILE_TO_EXTRACT}.zip"

# Check if the file already exists
if [ -f "$FILE_TO_EXTRACT.img" ]; then
    echo "--> Found '$FILE_TO_EXTRACT.img' directly in the archive."
    mv "$FILE_TO_EXTRACT.img" "$OUTPUT_IMG"
# If not, check for payload.bin and extract from it
elif [ -f "payload.bin" ]; then
    echo "--> payload.bin found, attempting to extract '$FILE_TO_EXTRACT'..."
    python3 /tools/payload_dumper.py --out . --images "$FILE_TO_EXTRACT" payload.bin

    if [ -f "$FILE_TO_EXTRACT.img" ]; then
        echo "--> Successfully extracted '$FILE_TO_EXTRACT.img'."
        mv "$FILE_TO_EXTRACT.img" "$OUTPUT_IMG"
    else
        echo "ERROR: Could not find or extract '$FILE_TO_EXTRACT' from payload.bin." >&2
        exit 1
    fi
else
    echo "ERROR: Neither '$FILE_TO_EXTRACT.img' nor 'payload.bin' were found in the ROM archive." >&2
    exit 1
fi

# --- Compression ---
echo "--> Compressing '$FILE_TO_EXTRACT.img' to ZIP..."
cd ../output
if ! zip -9 "$OUTPUT_ZIP" "${FILE_TO_EXTRACT}.img"; then
    echo "ERROR: Failed to compress the image." >&2
    exit 1
fi

# Delete the original .img after successful compression
rm -f "${FILE_TO_EXTRACT}.img"

echo "SUCCESS: Final file is available at '$OUTPUT_ZIP'"
echo "--> Done."
exit 0