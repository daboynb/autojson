#!/bin/bash

# Function to retry a command up to 3 times with a 30-second delay
retry() {
  local n=1
  local max=3
  local delay=30
  until "$@"; do
    if [[ $n -lt $max ]]; then
      ((n++))
      echo "Attempt $n/$max failed. Retrying in $delay seconds..."
      sleep $delay
    else
      echo "Attempt $n/$max failed. No more retries left."
      exit 1
    fi
  done
}

# Check for JSON files and remove them if they exist
find . -maxdepth 1 -name "*.json" -exec rm {} \;

# Check for backup files and remove them if they exist
find . -maxdepth 1 -name "*.bak" -exec rm {} \;

echo "Crawling Android Developers for latest Pixel Beta ..."

# Download the Pixel GSI HTML page with retry logic
retry wget -q -O PIXEL_GSI_HTML --no-check-certificate https://developer.android.com/topic/generic-system-image/releases 2>&1 || exit 1

# Extract the first occurrence of a Beta version from the HTML
grep -m1 -o 'li>.*(Beta)' PIXEL_GSI_HTML | cut -d\> -f2

# Get the release version, build ID, and incremental version
RELEASE="$(grep -m1 'corresponding Google Pixel builds' PIXEL_GSI_HTML | grep -o '/versions/.*' | cut -d\/ -f3)"
ID="$(grep -m1 -o 'Build:.*' PIXEL_GSI_HTML | cut -d\  -f2)"
INCREMENTAL="$(grep -m1 -o "$ID-.*-" PIXEL_GSI_HTML | cut -d- -f2)"

# Download the corresponding Google Pixel builds HTML page with retry logic
retry wget -q -O PIXEL_GET_HTML --no-check-certificate https://developer.android.com$(grep -m1 'corresponding Google Pixel builds' PIXEL_GSI_HTML | grep -o 'href.*' | cut -d\" -f2) 2>&1 || exit 1

# Download the factory images for Google Pixel with retry logic
retry wget -q -O PIXEL_BETA_HTML --no-check-certificate https://developer.android.com$(grep -m1 'Factory images for Google Pixel' PIXEL_GET_HTML | grep -o 'href.*' | cut -d\" -f2) 2>&1 || exit 1

# Extract model and product lists
MODEL_LIST="$(grep -A1 'tr id=' PIXEL_BETA_HTML | grep 'td' | sed 's;.*<td>\(.*\)</td>;\1;')"
PRODUCT_LIST="$(grep -o 'factory/.*_beta' PIXEL_BETA_HTML | cut -d\/ -f2)"

# Download the security bulletin for Pixel with retry logic
retry wget -q -O PIXEL_SECBULL_HTML --no-check-certificate https://source.android.com/docs/security/bulletin/pixel 2>&1 || exit 1

# Get the latest security patch level
SECURITY_PATCH="$(grep -A15 "$(grep -m1 -o 'Security patch level:.*' PIXEL_GSI_HTML | cut -d\  -f4-)" PIXEL_SECBULL_HTML | grep -m1 -B1 '</tr>' | grep 'td' | sed 's;.*<td>\(.*\)</td>;\1;')"

# Check for device matching
case "$1" in
  -m)
    DEVICE="$(getprop ro.product.device)"
    case "$PRODUCT_LIST" in
      *${DEVICE}_beta*)
        MODEL="$(getprop ro.product.model)"
        PRODUCT="${DEVICE}_beta"
      ;;
    esac
  ;;
esac

echo "Selecting Pixel Beta device ..."

# Always select the first one from the list 
set_latest_beta() {
    # Extract the first model and product from the list 
    MODEL="$(echo "$MODEL_LIST" | head -n 1)"
    PRODUCT="$(echo "$PRODUCT_LIST" | head -n 1)"
    DEVICE="$(echo "$PRODUCT" | sed 's/_beta//')"
}

# Call the function to set the latest beta
set_latest_beta

echo "$MODEL ($PRODUCT)"

echo "Dumping values to minimal pif.json ..."
cat <<EOF | tee pif.json
{
  "MANUFACTURER": "Google",
  "MODEL": "$MODEL",
  "FINGERPRINT": "google/$PRODUCT/$DEVICE:$RELEASE/$ID/$INCREMENTAL:user/release-keys",
  "PRODUCT": "$PRODUCT",
  "DEVICE": "$DEVICE",
  "SECURITY_PATCH": "$SECURITY_PATCH",
  "DEVICE_INITIAL_SDK_INT": "32"
}
EOF

# Remove temporary HTML files if they exist
find . -maxdepth 1 -name "*_HTML" -exec rm {} \;

# Add fields on chiteroman.json
./migrate_chiteroman.sh pif.json chiteroman.json
# I'll add this back when chiteroman will publish the release
#jq 'del(.BRAND, .PRODUCT, .DEVICE, .RELEASE, .ID, .INCREMENTAL, .TYPE, .TAGS, .spoofProvider, .spoofProps, .spoofSignature, .DEBUG)' chiteroman.json > tmp.json && mv tmp.json chiteroman.json

# Migrate osmosis
./migrate_osmosis.sh -a pif.json osmosis.json 

# Delete prev pif
rm pif.json

# No ts
cp osmosis.json device_osmosis.json 

# Adapt for tricky
jq '.spoofProps = "0" | .spoofProvider = "0"' osmosis.json  > tmp.json

# Get back original file
rm osmosis.json
mv tmp.json osmosis.json 

# Check for backup files and remove them if they exist
find . -maxdepth 1 -name "*.bak" -exec rm {} \;
