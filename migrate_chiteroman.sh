#!/bin/sh

N="
";

case "$1" in
  -h|--help|help) echo "sh migrate.sh [-f] [-o] [in-file] [out-file]"; exit 0;;
  -i|--install|install) INSTALL=1; shift;;
  *) echo "custom.pif.json migration script \
    $N  by osm0sis @ xda-developers $N";;
esac;

item() { echo "- $@"; }
die() { [ "$INSTALL" ] || echo "$N$N! $@"; exit 1; }
grep_get_json() {
  local target="$FILE";
  [ -n "$2" ] && target="$2";
  eval set -- "$(cat "$target" | tr -d '\r\n' | grep -m1 -o "$1"'".*' | cut -d: -f2-)";
  echo "$1" | sed -e 's|"|\\\\\\"|g' -e 's|[,}]*$||';
}
grep_check_json() {
  local target="$FILE";
  [ -n "$2" ] && target="$2";
  grep -q "$1" "$target" && [ "$(grep_get_json $1 "$target")" ];
}

until [ -z "$1" -o -f "$1" ]; do
  case "$1" in
    -f|--force|force) FORCE=1; shift;;
    -o|--override|override) OVERRIDE=1; shift;;
    *) die "Invalid argument/file not found: $1";;
  esac;
done;

if [ -f "$1" ]; then
  FILE="$1";
  DIR="$1";
else
  case "$0" in
    *.sh) DIR="$0";;
    *) DIR="$(lsof -p $$ 2>/dev/null | grep -o '/.*migrate.sh$')";;
  esac;
fi;
DIR=$(dirname "$(readlink -f "$DIR")");
[ -z "$FILE" ] && FILE="$DIR/custom.pif.json";

OUT="$2";
[ -z "$OUT" ] && OUT="$DIR/custom.pif.json";

[ -f "$FILE" ] || die "No json file found";

grep_check_json api_level && [ ! "$FORCE" ] && die "No migration required";

[ "$INSTALL" ] || item "Parsing fields ...";

FPFIELDS="BRAND PRODUCT DEVICE RELEASE ID INCREMENTAL TYPE TAGS";
ALLFIELDS="MANUFACTURER MODEL FINGERPRINT $FPFIELDS SECURITY_PATCH DEVICE_INITIAL_SDK_INT";

# Collect values for all fields
for FIELD in $ALLFIELDS; do
  eval $FIELD=\"$(grep_get_json $FIELD)\";
done;

if [ -n "$ID" ] && ! grep_check_json build.id; then
  item 'Simple entry ID found, changing to ID field and "*.build.id" property ...';
fi;

if [ -z "$ID" ] && grep_check_json BUILD_ID; then
  item 'Deprecated entry BUILD_ID found, changing to ID field and "*.build.id" property ...';
  ID="$(grep_get_json BUILD_ID)";
fi;

if [ -n "$SECURITY_PATCH" ] && ! grep_check_json security_patch; then
  item 'Simple entry SECURITY_PATCH found, changing to SECURITY_PATCH field and "*.security_patch" property ...';
fi;

if grep_check_json VNDK_VERSION; then
  item 'Deprecated entry VNDK_VERSION found, changing to "*.vndk.version" property ...';
  VNDK_VERSION="$(grep_get_json VNDK_VERSION)";
fi;

if [ -n "$DEVICE_INITIAL_SDK_INT" ] && ! grep_check_json api_level; then
  item 'Simple entry DEVICE_INITIAL_SDK_INT found, changing to DEVICE_INITIAL_SDK_INT field and "*api_level" property ...';
fi;

if [ -z "$DEVICE_INITIAL_SDK_INT" ] && grep_check_json FIRST_API_LEVEL; then
  item 'Deprecated entry FIRST_API_LEVEL found, changing to DEVICE_INITIAL_SDK_INT field and "*api_level" property ...';
  DEVICE_INITIAL_SDK_INT="$(grep_get_json FIRST_API_LEVEL)";
fi;

if [ -z "$RELEASE" -o -z "$INCREMENTAL" -o -z "$TYPE" -o -z "$TAGS" -o "$OVERRIDE" ]; then
  if [ "$OVERRIDE" ]; then
    item "Overriding values for fields derivable from FINGERPRINT ...";
  else
    item "Missing default fields found, deriving from FINGERPRINT ...";
  fi;
  IFS='/:' read F1 F2 F3 F4 F5 F6 F7 F8 <<EOF
$(grep_get_json FINGERPRINT)
EOF
  i=1;
  for FIELD in $FPFIELDS; do
    eval [ -z \"\$$FIELD\" -o \"$OVERRIDE\" ] \&\& $FIELD=\"\$F$i\";
    i=$((i+1));
  done;
fi;

if [ -z "$SECURITY_PATCH" -o "$SECURITY_PATCH" = "null" ]; then
  item 'Missing required SECURITY_PATCH field and "*.security_patch" property value found, leaving empty ...';
  unset SECURITY_PATCH;
fi;

if [ -z "$DEVICE_INITIAL_SDK_INT" -o "$DEVICE_INITIAL_SDK_INT" = "null" ]; then
  item 'Missing required DEVICE_INITIAL_SDK_INT field and "*api_level" property value found, setting to 25 ...';
  DEVICE_INITIAL_SDK_INT=25;
fi;

if [ -f "$OUT" ]; then
  item "Renaming old file to $(basename "$OUT").bak ...";
  mv -f "$OUT" "$OUT.bak";
fi;

[ "$INSTALL" ] || item "Writing fields and properties to updated custom.pif.json ...";

# Generate the JSON file while avoiding a trailing comma on the last field
(echo "{";
for FIELD in $ALLFIELDS; do
  LAST_FIELD="DEVICE_INITIAL_SDK_INT"
  if [ "$FIELD" != "$LAST_FIELD" ]; then
    eval echo '\ \ \ \ \"$FIELD\": \"'\$$FIELD'\",';
  else
    eval echo '\ \ \ \ \"$FIELD\": \"'\$$FIELD'\",';
    # Add the custom fields after DEVICE_INITIAL_SDK_INT
    echo "    \"spoofProvider\": true,";
    echo "    \"spoofProps\": true,";
    echo "    \"spoofSignature\": false,";
    echo "    \"DEBUG\": false";
  fi
done;
echo "}";
) > "$OUT";

[ "$INSTALL" ] || cat "$OUT";