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
if [[ ! "$URL" =~ \.zip(\?.*)?$ ]]; then # Corrected: removed extra 'then'
    echo "ERROR: Only .zip URLs are supported." >&2
    exit 1
fi

if ! aria2c -x16 -s16 -o rom.zip "$URL"; then
  echo "ERROR: Failed to download ROM." >&2
  exit 1
fi

mkdir -p extracted
mkdir -p ./output
OUTPUT_IMG="./output/${FILE_TO_EXTRACT}.img"
OUTPUT_ZIP="./output/${FILE_TO_EXTRACT}.zip"

# Check archive content by piping directly to grep, avoiding large variable storage
if 7z l -ba rom.zip | grep -q "$FILE_TO_EXTRACT.img"; then
    echo "--> Found '$FILE_TO_EXTRACT.img' directly in archive. Extracting it..."
    7z e -y rom.zip -o./output "$FILE_TO_EXTRACT.img"
    
elif 7z l -ba rom.zip | grep -q "payload.bin"; then
    echo "--> Found 'payload.bin' in archive. Extracting it..."
    7z e -y rom.zip -oextracted payload.bin
    
    echo "--> Processing payload.bin..."
    python3 /tools/payload_dumper.py --out ./output --images "$FILE_TO_EXTRACT" extracted/payload.bin
    
    if [ ! -f "$OUTPUT_IMG" ]; then
        echo "ERROR: Could not find or extract '$FILE_TO_EXTRACT' from payload.bin." >&2
        rm -f rom.zip
        exit 1
    fi
else
    echo "ERROR: Neither '$FILE_TO_EXTRACT.img' nor 'payload.bin' were found in the archive." >&2
    rm -f rom.zip
    exit 1
fi

rm -f rom.zip

cd ./output
if ! zip -9 "$OUTPUT_ZIP" "${FILE_TO_EXTRACT}.img"; then
    echo "ERROR: Failed to compress the image." >&2
    exit 1
fi
rm -f "${FILE_TO_EXTRACT}.img"

exit 0
