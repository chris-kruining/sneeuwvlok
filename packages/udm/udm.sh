usage() {
  echo "usage: udm [plan|apply]"
  echo "  plan   show what differs from the configuration (default)"
  echo "  apply  change it on the udm"
}

mode=${1:-plan}
case $mode in
  plan | apply) ;;
  -h | --help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

host=$(jq -r .host "$UDM_CONFIG")
site=$(jq -r .site "$UDM_CONFIG")
pin=$(jq -r .pinnedPublicKey "$UDM_CONFIG")
base="https://$host/proxy/network/api/s/$site"

# Read with the admin age key, or set UNIFI_API_KEY to use another key
key=${UNIFI_API_KEY:-$(sops decrypt --extract '["unifi"]["api_key"]' "$UDM_SECRETS")}

# The key goes in through a file descriptor, so it doesn't show in the process list
api() {
  curl --silent --show-error --fail-with-body --insecure --pinnedpubkey "$pin" \
    --header @<(printf 'X-API-KEY: %s\n' "$key") --header 'Accept: application/json' "$@"
}

changes=0

while IFS= read -r collection; do
  current=$(api "$base/rest/$collection" | jq .data)

  while IFS= read -r name; do
    desired=$(jq --arg c "$collection" --arg n "$name" '.rest[$c][$n]' "$UDM_CONFIG")
    matches=$(jq --arg n "$name" '[.[] | select(.name == $n)]' <<< "$current")

    count=$(jq length <<< "$matches")
    if [ "$count" -ne 1 ]; then
      echo "$collection/$name: $count objects with that name, expected 1" >&2
      exit 1
    fi

    object=$(jq '.[0]' <<< "$matches")
    diff=$(jq -r --argjson d "$desired" '
      . as $current | $d | to_entries[] | select($current[.key] != .value)
      | "  \(.key): \($current[.key] | tojson) -> \(.value | tojson)"' <<< "$object")

    if [ -z "$diff" ]; then
      echo "$collection/$name: up to date"
      continue
    fi

    echo "$collection/$name:"
    echo "$diff"
    changes=$((changes + 1))

    if [ "$mode" = apply ]; then
      id=$(jq -r ._id <<< "$object")
      # A partial object: the udm only changes the fields that are sent
      api --request PUT --header 'Content-Type: application/json' --data "$desired" "$base/rest/$collection/$id" \
        | jq -e --argjson d "$desired" '.data[0] as $o | $d | to_entries | all($o[.key] == .value)' > /dev/null \
        || { echo "  the udm didn't take it" >&2; exit 1; }
      echo "  applied"
    fi
  done < <(jq -r --arg c "$collection" '.rest[$c] | keys[]' "$UDM_CONFIG")
done < <(jq -r '.rest | keys[]' "$UDM_CONFIG")

if [ "$mode" = plan ] && [ "$changes" -gt 0 ]; then
  echo
  echo "$changes object(s) to change, run \`udm apply\` to change them"
fi
