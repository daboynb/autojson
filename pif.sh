#!/bin/bash

# RSS Feed URL
url="https://sourceforge.net/projects/xiaomi-eu-multilang-miui-roms/rss?path=/xiaomi.eu/Xiaomi.eu-app"

tmp_dir="$(mktemp -d)"
apk_file="${tmp_dir}/xiaomi.apk"
extracted_apk="${tmp_dir}/Extractedapk"
service_file="pif.json"

trap 'rm -rf "${tmp_dir}"' EXIT

# Fetch RSS feed and extract the last link
lastLink=$(curl --silent --show-error "${url}" | grep -oP '<link>\K[^<]+' | head -2 | tail -1)

# Output the last link
curl --silent --show-error --location --output "${apk_file}" "${lastLink}"

apktool d "${apk_file}" -o "${extracted_apk}" -f

# Function to set variable to "null" if empty
set_to_null() {
    if [ -z "$1" ]; then
        echo "null"
    else
        echo "$1"
    fi
}

# Assign values to variables
var_MANUFACTURER=$(grep 'MANUFACTURER' ${extracted_apk}/res/xml/inject_fields.xml | sed 's/.*value="\([^"]*\)".*/\1/' | sed 's/" \/>//')
var_BRAND=$(grep 'BRAND' ${extracted_apk}/res/xml/inject_fields.xml | sed 's/.*value="\([^"]*\)".*/\1/' | sed 's/" \/>//')
var_DEVICE=$(grep 'DEVICE' ${extracted_apk}/res/xml/inject_fields.xml | sed 's/.*value="\([^"]*\)".*/\1/' | sed 's/" \/>//')
var_PRODUCT=$(grep 'PRODUCT' ${extracted_apk}/res/xml/inject_fields.xml | sed 's/.*value="\([^"]*\)".*/\1/' | sed 's/" \/>//')
var_MODEL=$(grep 'MODEL' ${extracted_apk}/res/xml/inject_fields.xml | sed 's/.*value="\([^"]*\)".*/\1/' | sed 's/" \/>//')
var_FINGERPRINT=$(grep 'FINGERPRINT' ${extracted_apk}/res/xml/inject_fields.xml | sed 's/.*value="\([^"]*\)".*/\1/' | sed 's/" \/>//')
var_SECURITY_PATCH=$(grep 'SECURITY_PATCH' ${extracted_apk}/res/xml/inject_fields.xml | sed 's/.*value="\([^"]*\)".*/\1/' | sed 's/" \/>//')
var_FIRST_API_LEVEL=$(grep 'FIRST_API_LEVEL' ${extracted_apk}/res/xml/inject_fields.xml | sed 's/.*value="\([^"]*\)".*/\1/' | sed 's/" \/>//')

# Set variables to "null" if empty
var_MANUFACTURER=$(set_to_null "$var_MANUFACTURER")
var_BRAND=$(set_to_null "$var_BRAND")
var_DEVICE=$(set_to_null "$var_DEVICE")
var_PRODUCT=$(set_to_null "$var_PRODUCT")
var_MODEL=$(set_to_null "$var_MODEL")
var_FINGERPRINT=$(set_to_null "$var_FINGERPRINT")
var_SECURITY_PATCH=$(set_to_null "$var_SECURITY_PATCH")
var_FIRST_API_LEVEL=$(set_to_null "$var_FIRST_API_LEVEL")

# Create the json file
create_json() {
cat << EOF > ${service_file}
{
  "PRODUCT": "${var_PRODUCT}",
  "DEVICE": "${var_DEVICE}",
  "MANUFACTURER": "${var_MANUFACTURER}",
  "BRAND": "${var_BRAND}",
  "MODEL": "${var_MODEL}",
  "FINGERPRINT": "${var_FINGERPRINT}",
  "SECURITY_PATCH": "${var_SECURITY_PATCH}",
  "FIRST_API_LEVEL": "${var_FIRST_API_LEVEL}"
}
EOF
}

create_json

cat "${service_file}"
