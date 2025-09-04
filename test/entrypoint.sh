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
REPLACEMENT_DOMAIN="bkt-sgp-miui-ota-update-alisgp.oss-ap-southeast-1.aliyuncs.com"
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

echo "[INFO] Analyzing ROM structure..."
ROM_INFO=$(curl -s -I "$URL")
CONTENT_LENGTH=$(echo "$ROM_INFO" | grep -i "content-length" | awk '{print $2}' | tr -d '\r')

if [ -z "$CONTENT_LENGTH" ]; then
    echo "ERROR: Could not determine ROM size" >&2
    exit 1
fi

END_RANGE=$((CONTENT_LENGTH > 100000 ? 100000 : CONTENT_LENGTH))
curl -s -H "Range: bytes=$((CONTENT_LENGTH-END_RANGE))-$CONTENT_LENGTH" "$URL" > rom_tail.zip

ROM_CONTENTS=$(7z l -ba rom_tail.zip)
echo "$ROM_CONTENTS"

if echo "$ROM_CONTENTS" | grep -q "$FILE_TO_EXTRACT.img"; then
    FILE_INFO=$(7z l -ba rom_tail.zip | grep "$FILE_TO_EXTRACT.img")
    OFFSET=$(echo "$FILE_INFO" | awk '{print $3}')
    SIZE=$(echo "$FILE_INFO" | awk '{print $4}')
    echo "[INFO] Downloading only $FILE_TO_EXTRACT.img (offset: $OFFSET, size: $SIZE)"
    aria2c -x16 -s16 --console-log-level=warn --summary-interval=0 \
           --header="Range: bytes=$OFFSET-$((OFFSET+SIZE-1))" \
           -o "$FILE_TO_EXTRACT.img" "$URL"
    zip -9 "./output/${FILE_TO_EXTRACT}.zip" "$FILE_TO_EXTRACT.img"
    rm -f "$FILE_TO_EXTRACT.img"

elif echo "$ROM_CONTENTS" | grep -q "payload.bin"; then
    FILE_INFO=$(7z l -ba rom_tail.zip | grep "payload.bin")
    OFFSET=$(echo "$FILE_INFO" | awk '{print $3}')
    SIZE=$(echo "$FILE_INFO" | awk '{print $4}')
    echo "[INFO] Downloading only payload.bin"
    aria2c -x16 -s16 --console-log-level=warn --summary-interval=0 \
           --header="Range: bytes=$OFFSET-$((OFFSET+SIZE-1))" \
           -o "payload.bin" "$URL"
    python3 /tools/payload_dumper.py --out ./output --images "$FILE_TO_EXTRACT" payload.bin
    if [ ! -f "./output/${FILE_TO_EXTRACT}.img" ]; then
        echo "ERROR: Could not extract '$FILE_TO_EXTRACT' from payload.bin" >&2
        exit 1
    fi
    zip -9 "./output/${FILE_TO_EXTRACT}.zip" "./output/${FILE_TO_EXTRACT}.img"
    rm -f "./output/${FILE_TO_EXTRACT}.img" payload.bin
else
    echo "ERROR: Required files not found in ROM" >&2
    exit 1
fi

rm -f rom_tail.zip
echo "[DONE] Extracted and compressed: ./output/${FILE_TO_EXTRACT}.zip"