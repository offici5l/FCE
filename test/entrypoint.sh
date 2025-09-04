#!/bin/bash
set -e

mkdir -p ./output

for tool in aria2c 7z python3 zip; do
  if ! command -v "$tool" &> /dev/null; then
    echo "ERROR: Required tool '$tool' is not installed." >&2
    exit 1
  fi
done

if [ -z "${1-}" ] || [ -z "${2-}" ]; then
  echo "ERROR: ROM URL or file to extract not provided." >&2
  exit 1
fi
URL="$1"
FILE_TO_EXTRACT="$2"

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
REPLACEMENT_DOMAIN="cdn-ota.azureedge.net"
for domain in "${MIUI_DOMAINS[@]}"; do
  if [[ "$URL" == *"$domain"* ]]; then
    URL="${URL/$domain/$REPLACEMENT_DOMAIN}"
    break
  fi
done

if [[ ! "$URL" =~ \.zip(\?.*)?$ ]]; then
    echo "ERROR: Only .zip URLs are supported." >&2
    exit 1
fi

if ! aria2c -x16 -s16 --console-log-level=warn --summary-interval=1 -o rom.zip "$URL"; then
  echo "ERROR: Failed to download ROM." >&2
  exit 1
fi

OUTPUT_IMG="./output/${FILE_TO_EXTRACT}.img"
OUTPUT_ZIP="./output/${FILE_TO_EXTRACT}.zip"

echo "[INFO] Listing ROM contents..."
ROM_CONTENTS=$(7z l -ba rom.zip)
echo "$ROM_CONTENTS"

if echo "$ROM_CONTENTS" | grep -q "$FILE_TO_EXTRACT.img"; then
    echo "[INFO] Extracting $FILE_TO_EXTRACT.img directly..."
    if ! 7z e -so rom.zip "$FILE_TO_EXTRACT.img" | zip -9 "$OUTPUT_ZIP" - >/dev/null; then
        echo "ERROR: Failed to extract and compress $FILE_TO_EXTRACT.img" >&2
        rm -f rom.zip
        exit 1
    fi

elif echo "$ROM_CONTENTS" | grep -q "payload.bin"; then
    echo "[INFO] Extracting from payload.bin..."
    mkdir -p extracted
    7z e -y rom.zip -oextracted payload.bin
    
    python3 /tools/payload_dumper.py --out ./output --images "$FILE_TO_EXTRACT" extracted/payload.bin
    
    if [ ! -f "$OUTPUT_IMG" ]; then
        echo "ERROR: Could not find or extract '$FILE_TO_EXTRACT' from payload.bin." >&2
        rm -f rom.zip
        exit 1
    fi

    if ! zip -9 "$OUTPUT_ZIP" "$OUTPUT_IMG" >/dev/null; then
        echo "ERROR: Failed to compress the image." >&2
        rm -f rom.zip "$OUTPUT_IMG"
        exit 1
    fi
    rm -f "$OUTPUT_IMG"
else
    echo "ERROR: Neither '$FILE_TO_EXTRACT.img' nor 'payload.bin' were found in the archive." >&2
    rm -f rom.zip
    exit 1
fi

rm -f rom.zip
echo "[DONE] Extracted and compressed: $OUTPUT_ZIP"

exit 0