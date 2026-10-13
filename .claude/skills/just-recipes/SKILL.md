---
name: just-recipes
description: How to run this repo's just recipes (vars/secrets, users, machines), including from Windows through the NixOS WSL distro, and the naming convention for sops secrets. Use whenever reading, setting, generating or checking secrets, managing zitadel users, or building/deploying a machine.
shell: bash
allowed-tools: Bash(just *) Bash(nix develop *)
---

# Using the just recipes

All repo tooling lives in `.justfile` with submodules in `.just/`. These are the recipes right now (the output of the default recipe, `just`):

```!
just --justfile "${CLAUDE_PROJECT_DIR}/.justfile" --working-directory "${CLAUDE_PROJECT_DIR}" 2>/dev/null || nix develop "${CLAUDE_PROJECT_DIR}" -c just --justfile "${CLAUDE_PROJECT_DIR}/.justfile" --working-directory "${CLAUDE_PROJECT_DIR}"
```

Not shown in that list:

- private recipes, which can still be called: `vars _rotate <machine> <key>` (run the generator for one secret and store it) and `vars _check <machine>` (compare declared and stored secrets of one machine)
- `users …` manages zitadel users, stored in the `zitadel/users` secret on ulmo, and is interactive (`gum`)
- `machine update <machine>` runs `vars _check` first, then `nixos-rebuild switch --target-host`
- `update` commits `flake.lock` itself

Use the recipes instead of calling `sops` directly, they are what the user expects to be used.

## Running them

The tools (`sops`, `just`, `yq`, `pwgen`, `nom`, …) come from the devshell (`shells/default`), so always run inside it.

### On Linux / NixOS

```sh
nix develop -c just vars get ulmo synapse/shared_secret
```

### On Windows: go through the `NixOS` WSL distro

The Windows side has no `nix`, `sops` or `yq`. The `NixOS` WSL distro has nix, the user's age key (`~/.config/sops/age/keys.txt`) and the right git identity (`chris <chris@kruining.eu>`, which is what the secrets commits are authored as). The repo is at `/mnt/f/Forgejo/sneeuwvlok` there.

```sh
MSYS_NO_PATHCONV=1 wsl -d NixOS -- bash -lc 'cd /mnt/f/Forgejo/sneeuwvlok && nix develop path:. -c just vars get ulmo synapse/shared_secret'
```

Gotchas:

- `MSYS_NO_PATHCONV=1` is needed when calling from Git Bash, otherwise it mangles the `/mnt/...` paths.
- Use the flake ref `path:.` instead of `.` while there are untracked files: a git flake does not see them, so new modules simply don't exist. The same applies to recipes that evaluate `..#nixosConfigurations…` themselves (`vars _check`, `vars generate`, `machine check`): they only see committed or staged files, and `_check` then reports "up to date" even though its eval failed.
- For anything longer than a one-liner, write the script to a file and feed it over stdin: `MSYS_NO_PATHCONV=1 wsl -d NixOS -- bash -l -s < script.sh`. Nested quoting through `wsl … bash -lc '…'` breaks quickly.
- Files edited from Windows must keep LF line endings (`.gitattributes` has `eol=lf`). Windows Python rewriting a file writes CRLF, which breaks nix shell scripts (`$'do\r'`). Strip with `sed -i 's/\r$//' <file>`.

## Working with secrets

- `vars set` and `vars _rotate` **commit `secrets.yml` immediately** (`chore(secrets): set secret "<key>" for machine "<machine>"`). Don't run them unasked, and remember the commit lands on top of whatever is uncommitted.
- `vars list <machine>` shows only the keys, as a tree, use it to see which secrets exist. `vars values` and `vars edit` show the **values**, never run those.
- Never print a secret value into the conversation. Pipe it to where it's needed instead, e.g. deriving a public key:
  ```sh
  just vars get ulmo nix_cache/signing_key | jq -j -r . | nix key convert-secret-to-public
  ```
- Generated secrets: put a script at `script/<key>` (e.g. `script/nix_cache/signing_key`) that prints the value on stdout. `just vars _rotate <machine> <key>` runs it and stores the result, `just vars generate <machine>` does that for every secret the machine declares that has no value yet. `script/.shared/pwgen` is the generic random password.
- Secrets are declared in modules as `sops.secrets."<key>" = {};` and read via `config.sops.secrets."<key>".path` or `config.sops.placeholder."<key>"` in templates. They live in `systems/x86_64-linux/<machine>/secrets.yml`.

## Secret naming convention

`<service>/<name>`, optionally deeper (`sabnzbd/sunnyweb/password`), every segment **lowercase `snake_case`**:

- good: `synapse/shared_secret`, `grafana/oidc_secret`, `forgejo/action_runner_token`, `nix_cache/signing_key`
- the first segment is the service or module, using `_` even when the module directory uses `-` (module `nix-cache` → `nix_cache/…`)
- **never use `-` or `.`** in a key: `vars get` turns the key into a yq path like `.nix-cache.signing-key`, which breaks on both. And because `vars generate` checks for an existing value through `get`, such a key is silently regenerated on every run.
- `zitadel/masterKey` is a legacy camelCase exception, don't copy it.

If a name you picked clashes with the tooling, rename the key; don't change the just recipes to fit it.
