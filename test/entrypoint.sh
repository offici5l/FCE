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
    echo "ERROR: Only .zip URLs are supported."
    exit 1
fi

if ! aria2c -x16 -s16 -o rom.zip "$URL"; then
  echo "ERROR: Failed to download ROM." >&2
  exit 1
fi

# Clean the target directory before extraction to prevent overwrite prompts
rm -rf ./extracted
mkdir -p extracted

# Use -y flag to automatically say "yes" to any prompts from 7z
if ! 7z x -y rom.zip -oextracted; then
    echo "ERROR: Failed to extract ROM archive. Cleaning up..." >&2
    rm -f rom.zip
    exit 1
fi

rm -f rom.zip
cd extracted

mkdir -p ../output
OUTPUT_IMG="../output/${FILE_TO_EXTRACT}.img"
OUTPUT_ZIP="../output/${FILE_TO_EXTRACT}.zip"

if [ -f "$FILE_TO_EXTRACT.img" ]; then
    mv "$FILE_TO_EXTRACT.img" "$OUTPUT_IMG"
elif [ -f "payload.bin" ]; then
    python3 /tools/payload_dumper.py --out . --images "$FILE_TO_EXTRACT" payload.bin
    if [ -f "$FILE_TO_EXTRACT.img" ]; then
        mv "$FILE_TO_EXTRACT.img" "$OUTPUT_IMG"
    else
        echo "ERROR: Could not find or extract '$FILE_TO_EXTRACT' from payload.bin." >&2
        exit 1
    fi
else
    echo "ERROR: Neither '$FILE_TO_EXTRACT.img' nor 'payload.bin' were found in the ROM archive." >&2
    exit 1
fi

cd ../output
if ! zip -9 "$OUTPUT_ZIP" "${FILE_TO_EXTRACT}.img"; then
    echo "ERROR: Failed to compress the image." >&2
    exit 1
fi
rm -f "${FILE_TO_EXTRACT}.img"

exit 0