#!/bin/bash

rm *json

# RSS Feed URL
url="https://sourceforge.net/projects/xiaomi-eu-multilang-miui-roms/rss?path=/xiaomi.eu/Xiaomi.eu-app"

# Fetch RSS feed and extract the last link
lastLink=$(curl -s "$url" | grep -oP '<link>\K[^<]+' | head -2 | tail -1)

# Function to retry download up to 3 times
retry_count=0
max_retries=3

while [ $retry_count -lt $max_retries ]; do
    wget --user-agent="Wget" "$lastLink" -O xiaomi.apk
    if [ $? -eq 0 ]; then
        echo "Download succeeded!"
        break
    else
        retry_count=$((retry_count + 1))
        echo "Download failed. Attempt $retry_count of $max_retries."
    fi

    if [ $retry_count -eq $max_retries ]; then
        echo "Download failed after $max_retries attempts. Exiting."
        exit 1
    fi
done

apktool d xiaomi.apk -o Extractedapk -f

# Function to set variable to "null" if empty
set_to_null() {
    if [ -z "$1" ]; then
        echo "null"
    else
        echo "$1"
    fi
}

# Assign values to variables
var_MANUFACTURER=$(grep 'MANUFACTURER' Extractedapk/res/xml/inject_fields.xml | sed 's/.*value="\([^"]*\)".*/\1/' | sed 's/" \/>//')
var_BRAND=$(grep 'BRAND' Extractedapk/res/xml/inject_fields.xml | sed 's/.*value="\([^"]*\)".*/\1/' | sed 's/" \/>//')
var_DEVICE=$(grep 'DEVICE' Extractedapk/res/xml/inject_fields.xml | sed 's/.*value="\([^"]*\)".*/\1/' | sed 's/" \/>//')
var_PRODUCT=$(grep 'PRODUCT' Extractedapk/res/xml/inject_fields.xml | sed 's/.*value="\([^"]*\)".*/\1/' | sed 's/" \/>//')
var_MODEL=$(grep 'MODEL' Extractedapk/res/xml/inject_fields.xml | sed 's/.*value="\([^"]*\)".*/\1/' | sed 's/" \/>//')
var_FINGERPRINT=$(grep 'FINGERPRINT' Extractedapk/res/xml/inject_fields.xml | sed 's/.*value="\([^"]*\)".*/\1/' | sed 's/" \/>//')
var_SECURITY_PATCH=$(grep 'SECURITY_PATCH' Extractedapk/res/xml/inject_fields.xml | sed 's/.*value="\([^"]*\)".*/\1/' | sed 's/" \/>//')
var_FIRST_API_LEVEL=$(grep 'FIRST_API_LEVEL' Extractedapk/res/xml/inject_fields.xml | sed 's/.*value="\([^"]*\)".*/\1/' | sed 's/" \/>//')

# Set variables to "null" if empty
var_MANUFACTURER=$(set_to_null "$var_MANUFACTURER")
var_BRAND=$(set_to_null "$var_BRAND")
var_DEVICE=$(set_to_null "$var_DEVICE")
var_PRODUCT=$(set_to_null "$var_PRODUCT")
var_MODEL=$(set_to_null "$var_MODEL")
var_FINGERPRINT=$(set_to_null "$var_FINGERPRINT")
var_SECURITY_PATCH=$(set_to_null "$var_SECURITY_PATCH")
var_FIRST_API_LEVEL=$(set_to_null "$var_FIRST_API_LEVEL")

PIF_FILE="pif.json"

# Create the json file
create_json() {
cat << EOF > ${PIF_FILE}
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

cat pif.json

./chiteroman.sh pif.json chiteroman.json
./osmosis.sh pif.json osmosis.json

rm -rf Extractedapk
rm *.apk

# Update 26/09/24: I’ve notified the EU team about the build.prop repo, as they are better than I am at automating the process of pulling new fingerprints when burned, since I don’t have something that notifies me when a fingerprint is banned. I’ve started pulling from them again