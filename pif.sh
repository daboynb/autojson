#!/bin/bash

# Print a message indicating the start of the crawling process
echo "Crawling Android Developers for latest Pixel Beta ..."

# Download the Android versions page and save it to PIXEL_VERSIONS_HTML
wget -q -O PIXEL_VERSIONS_HTML --no-check-certificate https://developer.android.com/about/versions 2>&1 || exit 1

# Extract the latest versions URL from PIXEL_VERSIONS_HTML
# Download the latest version page and save it to PIXEL_LATEST_HTML
wget -q -O PIXEL_LATEST_HTML --no-check-certificate $(grep -o 'https://developer.android.com/about/versions/.*[0-9]"' PIXEL_VERSIONS_HTML | sort -ru | cut -d\" -f1 | head -n1) 2>&1 || exit 1

# Check if the first argument is '-p' to force preview mode
case "$1" in
  -p)
    FORCE_PREVIEW=1
    shift
    ;;
esac

# Determine if the latest HTML contains a Developer Preview or preview program tooltip
# and if FORCE_PREVIEW is not set, download the second latest version
if grep -qE 'Developer Preview|tooltip>.*preview program' PIXEL_LATEST_HTML && [ ! "$FORCE_PREVIEW" ]; then
  wget -q -O PIXEL_BETA_HTML --no-check-certificate $(grep -o 'https://developer.android.com/about/versions/.*[0-9]"' PIXEL_VERSIONS_HTML | sort -ru | cut -d\" -f1 | head -n2 | tail -n1) 2>&1 || exit 1
else
  # If not a preview, set TITLE to "Preview" and rename PIXEL_LATEST_HTML to PIXEL_BETA_HTML
  TITLE="Preview"
  mv -f PIXEL_LATEST_HTML PIXEL_BETA_HTML
fi

# Check if the first argument is '-d' to set FORCE_DEPTH
case "$1" in
  -d)
    FORCE_DEPTH=$2
    shift 2
    ;;
  *)
    FORCE_DEPTH=1
    ;;
esac

# Download the OTA (Over-The-Air) update page based on FORCE_DEPTH
# Extract the OTA download link from PIXEL_BETA_HTML
wget -q -O PIXEL_OTA_HTML --no-check-certificate https://developer.android.com$(grep -o 'href=".*download-ota.*"' PIXEL_BETA_HTML | cut -d\" -f2 | head -n$FORCE_DEPTH | tail -n1) 2>&1 || exit 1

# Extract and print the Android version and Beta title from PIXEL_OTA_HTML
echo "$(grep -m1 -oE 'tooltip>Android .*[0-9]' PIXEL_OTA_HTML | cut -d\> -f2) $TITLE$(grep -oE 'tooltip>QPR.* Beta' PIXEL_OTA_HTML | cut -d\> -f2 | head -n$FORCE_DEPTH | tail -n1)"

# Extract the release date from PIXEL_OTA_HTML and format it as YYYY-MM-DD
BETA_REL_DATE="$(date -d "$(grep -m1 -A1 'Release date' PIXEL_OTA_HTML | tail -n1 | sed 's;.*<td>\(.*\)</td>.*;\1;')" '+%Y-%m-%d')"

# Calculate the estimated expiry date by adding 6 weeks to the release date
BETA_EXP_DATE="$(date -d "@$(($(date -d "$BETA_REL_DATE" '+%s') + 60 * 60 * 24 * 7 * 6))" '+%Y-%m-%d')"

# Print the beta release and estimated expiry dates
echo "Beta Released: $BETA_REL_DATE \
  \nEstimated Expiry: $BETA_EXP_DATE"

# Extract lists of models, products, and OTA links from PIXEL_OTA_HTML
MODEL_LIST="$(grep -A1 'tr id=' PIXEL_OTA_HTML | grep 'td' | sed 's;.*<td>\(.*\)</td>;\1;')"
PRODUCT_LIST="$(grep -o 'ota/.*_beta' PIXEL_OTA_HTML | cut -d\/ -f2)"
OTA_LIST="$(grep 'ota/.*_beta' PIXEL_OTA_HTML | cut -d\" -f2)"

# Check if the first argument is '-m' to select a specific device
case "$1" in
  -m)
    # Get the device identifier from system properties
    DEVICE="$(getprop ro.product.device)"
    
    # Check if the device is in the PRODUCT_LIST
    case "$PRODUCT_LIST" in
      *${DEVICE}_beta*)
        # Get the model name from system properties
        MODEL="$(getprop ro.product.model)"
        PRODUCT="${DEVICE}_beta"
        # Find the corresponding OTA link for the product
        OTA="$(echo "$OTA_LIST" | grep "$PRODUCT")"
        ;;
    esac
    ;;
esac

# Inform the user that a Pixel Beta device is being selected
echo "Selecting Pixel Beta device ..."

# If no specific product was selected, choose a random beta device
if [ -z "$PRODUCT" ]; then
  set_random_beta() {
    # Get the count of available models
    local list_count="$(echo "$MODEL_LIST" | wc -l)"
    # Select a random number within the list count
    local list_rand="$((RANDOM % list_count + 1))"
    # Set Internal Field Separator to newline for proper splitting
    local IFS=$'\n'
    
    # Select the MODEL based on the random index
    set -- $MODEL_LIST
    MODEL="$(eval echo \${$list_rand})"
    
    # Select the PRODUCT based on the random index
    set -- $PRODUCT_LIST
    PRODUCT="$(eval echo \${$list_rand})"
    
    # Select the OTA link based on the random index
    set -- $OTA_LIST
    OTA="$(eval echo \${$list_rand})"
    
    # Derive the DEVICE identifier from the PRODUCT by removing '_beta'
    DEVICE="$(echo "$PRODUCT" | sed 's/_beta//')"
  }
  
  # Call the function to set a random beta device
  set_random_beta
fi

# Print the selected model and product
echo "$MODEL ($PRODUCT)"

# Download the OTA metadata with a file size limit to prevent excessive downloads
# - ulimit -f 2: Limit the file size to 2 blocks (typically 1KB)
# Redirect stderr to /dev/null to suppress error messages
(ulimit -f 2; wget -q -O PIXEL_ZIP_METADATA --no-check-certificate $OTA) 2>/dev/null

# Extract the fingerprint from the metadata
FINGERPRINT="$(grep -am1 'post-build=' PIXEL_ZIP_METADATA | cut -d= -f2)"

# Extract the security patch level from the metadata
SECURITY_PATCH="$(grep -am1 'security-patch-level=' PIXEL_ZIP_METADATA | cut -d= -f2)"

# Check if both FINGERPRINT and SECURITY_PATCH were successfully extracted
if [ -z "$FINGERPRINT" ] || [ -z "$SECURITY_PATCH" ]; then
  echo "\nError: Failed to extract information from metadata!"
  exit 1
fi

# Inform the user that values are being dumped to pif.json
echo "Dumping values to minimal pif.json ..."

# Create pif.json with the extracted information
cat <<EOF | tee pif.json
{
  "MANUFACTURER": "Google",
  "MODEL": "$MODEL",
  "FINGERPRINT": "$FINGERPRINT",
  "PRODUCT": "$PRODUCT",
  "DEVICE": "$DEVICE",
  "SECURITY_PATCH": "$SECURITY_PATCH",
  "DEVICE_INITIAL_SDK_INT": "32"
}
EOF

# Remove temporary HTML files if they exist
find . -maxdepth 1 -name "*_HTML" -exec rm {} \;
find . -maxdepth 1 -name "*_METADATA" -exec rm {} \;

# Migrate data using migrate.sh script
# Save original pif.json as base for migration
mv pif.json pif_base.json

# pif.json: for STRONG integrity with Tricky Store + hardware keybox
# Note: Pixel Beta fingerprints can NO LONGER pass DEVICE integrity
# They can ONLY be used for STRONG integrity setups with Tricky Store
# spoofProvider=0 required, spoofBuild=1 and spoofProps=1 for fingerprint spoofing
# Requires *api_level > 25 (we use 32)
./migrate.sh -f -a pif_base.json pif.json
# Remove // comments for jq compatibility
sed -i 's|//.*||g; /^[[:space:]]*$/d' pif.json
jq '(.spoofBuild, .spoofProps) = "1" | (.spoofProvider, .spoofSignature, .spoofVendingFinger, .spoofVendingSdk) = "0"' pif.json > tmp.json && mv tmp.json pif.json

# Remove temporary file
rm pif_base.json

# Remove any backup files with the .bak extension if they exist
find . -maxdepth 1 -name "*.bak" -exec rm {} \;

# Update README with current JSON contents
echo "Updating README.md with current fingerprints ..."

# Function to update a README section
update_readme_section() {
  local start_marker="$1"
  local end_marker="$2"
  local json_file="$3"
  local readme="Readme.md"

  # Create new content with markers
  local new_content=$(cat <<EOF
$start_marker
\`\`\`json
$(cat "$json_file")
\`\`\`
$end_marker
EOF
)

  # Use awk to replace content between markers
  awk -v start="$start_marker" -v end="$end_marker" -v content="$new_content" '
    $0 ~ start { found=1; print content; next }
    $0 ~ end { found=0; next }
    !found { print }
  ' "$readme" > "${readme}.tmp" && mv "${readme}.tmp" "$readme"
}

# Update README section
update_readme_section "<!-- PIF_JSON_START -->" "<!-- PIF_JSON_END -->" "pif.json"
