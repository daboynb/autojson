#!/bin/bash

get_value() {
  value="$(grep "$1" "${fields_file}" | sed 's/.*value="\([^"]*\)".*/\1/' | sed 's/" \/>//')"
  echo "${value:-null}"
}

# Create the json file
create_json() {
  cat <<EOF >"${service_file}"
{
  "PRODUCT": "$(get_value PRODUCT)",
  "DEVICE": "$(get_value DEVICE)",
  "MANUFACTURER": "$(get_value MANUFACTURER)",
  "BRAND": "$(get_value BRAND)",
  "MODEL": "$(get_value MODEL)",
  "FINGERPRINT": "$(get_value FINGERPRINT)",
  "SECURITY_PATCH": "$(get_value SECURITY_PATCH)",
  "FIRST_API_LEVEL": "$(get_value FIRST_API_LEVEL)"
}
EOF
}

# RSS Feed URL
url="https://sourceforge.net/projects/xiaomi-eu-multilang-miui-roms/rss?path=/xiaomi.eu/Xiaomi.eu-app"

tmp_dir="$(mktemp -d)"
apk_file="${tmp_dir}/xiaomi.apk"
extracted_apk="${tmp_dir}/Extractedapk"
service_file="pif.json"
fields_file="${extracted_apk}/res/xml/inject_fields.xml"

trap 'rm -rf "${tmp_dir}"' EXIT

# Fetch RSS feed and extract the last link
lastLink=$(curl --silent --show-error "${url}" | grep -oP '<link>\K[^<]+' | head -2 | tail -1)

# Output the last link
# Loop until the file is downloaded successfully
while true; do
  if curl --silent --show-error --location --output "${apk_file}" "${lastLink}"; then
    echo "File downloaded successfully."
    break
  else
    echo "Download failed. Retrying in 2 minutes..."
    sleep 120
  fi
done

apktool d "${apk_file}" -o "${extracted_apk}" -f

create_json

cat "${service_file}"

# Use the Osmosis's migrate.sh script to adapt the values
chmod +x *.sh

# I know they are duplicates, I'm making some tests
./migrate_chiteroman.sh -i "${service_file}" edited.json

mv edited.json pif.json

./migrate_chiteroman.sh -i "${service_file}" edited.json

mv edited.json chiteroman.json

jq 'del(.RELEASE)' chiteroman.json > chiteroman_modified.json

mv chiteroman_modified.json chiteroman.json

./migrate_osmosis.sh -i "${service_file}" edited.json

mv edited.json osmosis.json

# Since the eu team sould now use build.prop, I can again download from them, since I don't have an automate way to check for bans.

# while true; do
#   if wget https://raw.githubusercontent.com/daboynb/build.prop/main/chiteroman.json; then
#     echo "File downloaded successfully."
#     break
#   else
#     echo "Download failed. Retrying in 3 seconds..."
#     sleep 3
#   fi
# done

# while true; do
#   if wget https://raw.githubusercontent.com/daboynb/build.prop/main/osmosis.json; then
#     echo "File downloaded successfully."
#     break
#   else
#     echo "Download failed. Retrying in 3 seconds..."
#     sleep 3
#   fi
# done