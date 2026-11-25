---
name: openspec-worktree
description: Apply an OpenSpec change in its own git worktree and Herdr space, then archive, rebase, merge and clean up on its own. Use whenever the user asks to apply, implement or start an OpenSpec change (`/opsx:apply`, "apply <change>"), and when a task says to use this skill as the worker.
license: MIT
metadata:
  author: chris
  version: "1.0"
---

Applies an OpenSpec change in parallel with other work: every change gets its own worktree and branch, and its own
space in the Herdr app with an agent that implements it, archives it, merges it into the base branch and cleans up
after itself. The space shows the agent working, blocked or done like any other.

The scripts are next to this file: `~/.copilot/skills/openspec-worktree/` for copilot, `~/.claude/skills/openspec-worktree/`
for claude code. Below, `<skill>` is that folder.

There are two roles. Which one you are follows from how you got here.

## Starter: the user asked to apply a change

1. **Pick the change.** Use the name the user gave. Otherwise run `openspec list --json`: take the only active one,
   or ask which. Several names means several changes, start each.

2. **Check it is ready.** `openspec status --change "<name>" --json`. When artifacts are missing, say so and stop; don't
   start a worker for an incomplete change.

3. **Check you can start one.** `HC_TERMINAL_ID` must be set (you run in the Herdr app) and you must be in the repo's
   main checkout, not a worktree. If not, explain why and offer to apply it here instead with the normal apply workflow.

4. **Start it.** From the main checkout:

   ```bash
   bash <skill>/start.sh "<name>" copilot   # or claude, the same agent you are
   ```

   It creates branch `openspec/<name>` from the current branch in `~/.herdr/worktrees/<repo>/openspec-<name>`, moves the
   change there if it isn't committed yet, and opens a Herdr space named after the change with an agent that is told
   to be the worker.

5. **Report and stop.** Tell the user it runs in the space `<name>`. Don't implement anything yourself and don't wait
   for it; the user follows it in Herdr.

## Worker: your task says to use this skill as the worker

Your task names the change, its branch, the base branch and the main checkout. You are in the worktree.

1. **Implement.** Follow the OpenSpec apply workflow:
   - `openspec instructions apply --change "<name>" --json`, then read every file in `contextFiles`.
   - Work through the pending tasks in order, marking each `- [ ]` as `- [x]` in the tasks file when it is done.
   - Build or test what you changed, the way the repo does it (its README, CONTRIBUTING.md and skills say how).
   - When a task is unclear or the design turns out wrong, stop and ask. The space shows as blocked until the user answers.
   - Commit as you go, in the repo's commit style.

2. **Archive.** When every task is done:
   `openspec archive "<name>" --yes` (add `--skip-specs` only for a change without spec deltas), then commit the archive.

3. **Merge and clean up.**

   ```bash
   bash <skill>/finish.sh "<base branch>" "<main checkout>"
   ```

   It rebases on the base branch, fast-forwards the base branch in the main checkout, removes the worktree and the
   branch, and closes this space, which ends you. Before running it, give a one-paragraph summary of what you did:
   it is the last thing left in the session (`copilot --resume`).

   - **Exit 2, conflicts:** resolve them. Where the intent of both sides is clear (lock files, neighbouring edits,
     both adding to a list), resolve and `git rebase --continue`, then run `finish.sh` again. Where it isn't, ask
     the user first.
   - **Other errors:** usually uncommitted changes in the main checkout to the same files, or the main checkout on
     another branch. Don't touch the main checkout's uncommitted work; tell the user and wait.

Never push, and never force anything: no `--force`, no `reset --hard`, no deleting unmerged branches.
