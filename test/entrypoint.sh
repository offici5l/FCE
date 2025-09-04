#!/bin/bash
set -e

mkdir -p ./output

# Check for python3
if ! command -v python3 &> /dev/null; then
    echo "ERROR: python3 is not installed." >&2
    exit 1
fi

if [ -z "${1-}" ] || [ -z "${2-}" ]; then
  echo "ERROR: ROM URL or file to extract not provided." >&2
  exit 1
fi
URL="$1"
FILE_TO_EXTRACT="$2"

# Domain replacement logic remains the same
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

# Call the new python script
python3 fast_extractor.py "$URL" "$FILE_TO_EXTRACT"

exit 0
