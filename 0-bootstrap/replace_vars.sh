#!/bin/bash

set -e

cd "$(dirname "$0")"

PROJECT_ROOT="$(cd .. && pwd)"
VALUES_FILE="$PROJECT_ROOT/values.yaml"

if [ ! -f "$VALUES_FILE" ]; then
  echo "Cannot find $VALUES_FILE"
  exit 1
fi

TMP_KV=".__flattened_kv.tmp"

yq eval '.global | to_entries | .[] | select(.value | tag != "!!map") | "\(.key)=\(.value)"' "$VALUES_FILE" > "$TMP_KV"
yq eval '.global | to_entries | .[] | select(.value | tag == "!!map") | . as $root | .value | to_entries | .[] | "\($root.key)-\(.key)=\(.value)"' "$VALUES_FILE" >> "$TMP_KV"

declare -a kvs
while IFS='=' read -r k v; do
  [ -z "$k" ] && continue
  kvs+=("$k=$v")
done < "$TMP_KV"

find "$PROJECT_ROOT" \( -name "*.yaml" -o -name "*.yml" \) | while read -r file; do
  [[ "$file" == "$VALUES_FILE" || "$file" == "$0" ]] && continue
  echo "Processing $file"
  for kv in "${kvs[@]}"; do
    k="${kv%%=*}"
    v="${kv#*=}"
    perl -pi -e "s|\\\${$k}|$v|g" "$file"
  done
done

rm "$TMP_KV"

echo "All parameters have been processed."
