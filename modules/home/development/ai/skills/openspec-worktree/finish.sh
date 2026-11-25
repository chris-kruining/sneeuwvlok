#!/usr/bin/env bash
# Run by the worker, from its worktree, once the change is archived and committed. Rebases the branch on the base branch,
# fast-forwards the base branch to it, removes the worktree and branch, and closes this Herdr space (ending this agent).
# Usage: finish.sh <base-branch> <main-checkout>
# Exits 2 when the rebase stops on conflicts; resolve them, `git rebase --continue`, and run it again.
set -euo pipefail

base="${1:?usage: finish.sh <base-branch> <main-checkout>}"
main="${2:?usage: finish.sh <base-branch> <main-checkout>}"

wt="$(git rev-parse --show-toplevel)"
branch="$(git branch --show-current)"
[ "$wt" != "$main" ] || { echo "error: run this from the worktree, not the main checkout" >&2; exit 1; }
[ -n "$branch" ] || { echo "error: detached HEAD, is a rebase still running?" >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "error: the worktree has uncommitted changes, commit them first" >&2; exit 1; }

# Other changes can merge in the meantime, so rebase until the fast-forward goes through
for _ in 1 2 3 4 5; do
  if ! git rebase -q "$base"; then
    echo "conflicts rebasing $branch on $base: resolve them, run \`git rebase --continue\`, then run this again" >&2
    exit 2
  fi

  [ "$(git -C "$main" branch --show-current)" = "$base" ] || {
    echo "error: the main checkout isn't on $base anymore" >&2
    exit 1
  }

  # Refuses, without changing anything, when the main checkout has uncommitted changes to the same files
  if git -C "$main" merge -q --ff-only "$branch"; then
    merged=1
    break
  fi

  [ "$(git rev-parse "$base")" != "$(git merge-base "$base" HEAD)" ] || {
    echo "error: fast-forward refused, see above (uncommitted changes in $main?)" >&2
    exit 1
  }
done
[ "${merged:-}" = 1 ] || { echo "error: $base kept moving, giving up" >&2; exit 1; }

echo "merged $branch into $base"

# From the main checkout, the worktree is about to go
cd "$main"
git worktree remove "$wt"
git branch -q -d "$branch"
echo "removed $wt and $branch"

# Last: closing the space ends this terminal and the agent in it
space="$(hc get "${HC_TERMINAL_ID:?not running in the Herdr app}" --json | jq -r '.labels["herdr.space"] // empty')"
if [ -n "$space" ]; then
  herdr-app do space.close "$(jq -n --arg id "$space" '{id: $id, confirmed: true}')" >/dev/null
fi
