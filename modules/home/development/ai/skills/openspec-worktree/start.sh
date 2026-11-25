#!/usr/bin/env bash
# Starts an OpenSpec change in its own worktree, in its own Herdr space, with an agent that implements and merges it.
# Usage: start.sh <change> [copilot|claude]
set -euo pipefail

change="${1:?usage: start.sh <change> [copilot|claude]}"
agent="${2:-copilot}"

main="$(git rev-parse --show-toplevel)"
if [ "$(git -C "$main" rev-parse --git-common-dir)" != "$(git -C "$main" rev-parse --git-dir)" ]; then
  echo "error: run this from the main checkout, not from a worktree" >&2
  exit 1
fi

base="$(git -C "$main" branch --show-current)"
[ -n "$base" ] || { echo "error: the main checkout has a detached HEAD" >&2; exit 1; }

dir="openspec/changes/$change"
[ -d "$main/$dir" ] || { echo "error: no change at $main/$dir" >&2; exit 1; }

repo="$(basename "$main")"
branch="openspec/$change"
# Where the Herdr app's own worktree dialog puts them, so they look the same in the app
path="$HOME/.herdr/worktrees/$repo/openspec-$change"

if git -C "$main" show-ref --verify --quiet "refs/heads/$branch"; then
  echo "error: branch $branch already exists, is the change already running?" >&2
  exit 1
fi

case "$agent" in
  copilot) argv='["copilot","--yolo"]' ;;
  claude) argv='["claude","--dangerously-skip-permissions"]' ;;
  *) echo "error: unknown agent $agent" >&2; exit 1 ;;
esac

git -C "$main" worktree add -q -b "$branch" "$path" "$base"

# A change that isn't committed yet only exists in the main checkout. It moves to the worktree, where the agent commits it,
# else the main checkout's copy would block the merge back
if [ -n "$(git -C "$main" status --porcelain -- "$dir")" ]; then
  rm -rf "${path:?}/$dir"
  mkdir -p "$(dirname "$path/$dir")"
  cp -a "$main/$dir" "$path/$dir"
  git -C "$main" checkout -q HEAD -- "$dir" 2>/dev/null || true
  git -C "$main" clean -fdq -- "$dir"
  echo "moved the uncommitted change from the main checkout into the worktree"
fi

task="Use the openspec-worktree skill as the worker. Change: $change. Branch: $branch. Base branch: $base. Main checkout: $main."

herdr-app do space.new "$(jq -n \
  --arg name "$change" --arg folder "$path" --arg task "$task" --argjson argv "$argv" \
  '{name: $name, folder: $folder, tab: "agent", argv: $argv, task: $task, machine: ""}')"

echo "started $change in $path on $branch"
