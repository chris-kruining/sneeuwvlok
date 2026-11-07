#!/usr/bin/env bash
# Builds the caddy package, and when its hash is stale puts the right one in default.nix
set -euo pipefail

dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
file="$dir/default.nix"
root=$(git -C "$dir" rev-parse --show-toplevel)
fake="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

if nix build --no-link "$root#caddy" 2> /dev/null; then
  echo "caddy: hash is up to date"
  exit 0
fi

current=$(grep -o 'sha256-[A-Za-z0-9+/]*=' "$file")
sed -i "s|$current|$fake|" "$file"

# The new file has to be what the flake sees, a dirty tree is read as is
log=$(nix build --no-link "$root#caddy" 2>&1 || true)
new=$(grep -o 'got: *sha256-[A-Za-z0-9+/]*=' <<< "$log" | grep -o 'sha256-.*' | head -1 || true)

if [ -z "$new" ]; then
  sed -i "s|$fake|$current|" "$file"
  echo "caddy: the build fails, but not on the hash:" >&2
  tail -n 20 <<< "$log" >&2
  exit 1
fi

sed -i "s|$fake|$new|" "$file"
echo "caddy: hash updated to $new"
