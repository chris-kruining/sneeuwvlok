# Description

My work laptop, reasoning for the name being the following chain of thought:  
**Orome -> the huntsman -> hunting means leaving home -> work laptop travels with me**

# Installing

With nixos-anywhere, from another machine that has nix and this repo (e.g. manwe). It wipes the disk and partitions it as `disks.nix` describes.

1. Boot orome from a NixOS installer stick, connect to wifi (`nmtui`) and make root reachable over ssh:
   ```sh
   sudo passwd root
   ip -brief address
   ```
2. On the other machine, put an ssh key on the installer and write the luks passphrase to a file outside the repo:
   ```sh
   ssh-copy-id root@<ip>
   read -rs pass && printf '%s' "$pass" > /tmp/orome-luks && unset pass
   ```
3. Install, from the devshell (`nix develop`). orome's ssh host key comes along, sops decrypts orome's secrets with it.
   The hardware report is written into the repo first, it has to be known to git before nix evaluates the flake:
   ```sh
   extra=$(mktemp -d) && install -d -m 755 "$extra/etc/ssh"
   (umask 077 && just vars get orome ssh/host_ed25519_key | jq -j -r . > "$extra/etc/ssh/ssh_host_ed25519_key")
   cp systems/x86_64-linux/orome/ssh_host_ed25519_key.pub "$extra/etc/ssh/"

   touch systems/x86_64-linux/orome/facter.json && git add --intent-to-add systems/x86_64-linux/orome/facter.json
   nix run nixpkgs#nixos-anywhere -- \
     --flake .#orome \
     --target-host root@<ip> \
     --phases disko,install \
     --generate-hardware-config nixos-facter systems/x86_64-linux/orome/facter.json \
     --disk-encryption-keys /tmp/secret.key /tmp/orome-luks \
     --extra-files "$extra"
   rm -rf "$extra" /tmp/orome-luks
   ```
   Leaving out the `reboot` phase keeps the new system mounted on `/mnt`.
4. Give `chris` a password, nothing declares one and it is the way in when himmelblau is not working. Then reboot:
   ```sh
   ssh -t root@<ip> "nixos-enter --root /mnt -c 'passwd chris' && reboot"
   ```
5. Commit `facter.json`.

# First boot

Logging in is local, as `chris` with the password from the install.

1. Enroll a finger, it unlocks the lockscreen and sudo (logging in keeps the password, it unlocks kwallet):
   ```sh
   fprintd-enroll
   ```
2. Sign in to Entra once, this sets up the hello pin and gives the broker its token. Apps then get single sign-on as `c.kruining@4dotnet.nl`:
   ```sh
   sudo aad-tool auth-test --name c.kruining@4dotnet.nl
   ```
   After every reboot the broker asks for that pin once, the first time an app wants a token.
3. Open Helium, the Linux Entra SSO extension is installed by policy, then sign in to Teams/Outlook without a password prompt.

# Moving over from Windows

## Helium

Its extensions install themselves from the web store on the first start, bitwarden gets its server (`vault.kruining.eu`) through
policy, the rest have no managed storage. Their settings and the open tabs and tab groups come along in a bundle that is encrypted
for orome (`helium-profile.sops`, like `secrets.yml`), sops-nix decrypts it to `/run/secrets/helium/profile`. It also holds
bitwarden's vault key, that is how it arrives unlocked without the master password. Cookies and saved passwords don't come along,
windows encrypted those for that machine. uBlock's own storage is mostly its cache, only its backup file comes along.

1. On windows, right before the wipe: uBlock dashboard, settings, "back up to file", saved as `Downloads\ublock-backup.txt`.
2. Close helium, then from this repo (PowerShell), which also commits and pushes it:
   ```powershell
   $p = "$env:LOCALAPPDATA\imput\Helium\User Data\Default"
   $ublock = "blockjmkbacgjkknlgpkjjiijinjdanf"
   $t = New-Item -ItemType Directory "$env:TEMP\helium-profile" -Force
   Copy-Item "$p\Sessions" $t -Recurse
   foreach ($d in "Local Extension Settings", "Sync Extension Settings") {
     Copy-Item "$p\$d" $t -Recurse
     Remove-Item "$t\$d\$ublock" -Recurse -Force -ErrorAction SilentlyContinue
   }
   New-Item -ItemType Directory "$t\IndexedDB" -Force | Out-Null
   Get-ChildItem "$p\IndexedDB" -Directory -Filter "chrome-extension_*" | Where-Object Name -notlike "*$ublock*" | Copy-Item -Destination "$t\IndexedDB" -Recurse
   Copy-Item "$HOME\Downloads\ublock-backup.txt" $t
   Compress-Archive "$t\*" "$env:TEMP\helium-profile.zip" -Force
   Remove-Item $t -Recurse -Force

   wsl -d NixOS -- bash -lc 'cd /mnt/f/Forgejo/sneeuwvlok && nix develop -c sops encrypt --filename-override systems/x86_64-linux/orome/helium-profile.sops --input-type binary --output-type binary /mnt/c/Users/ChrisKruining/AppData/Local/Temp/helium-profile.zip > systems/x86_64-linux/orome/helium-profile.sops'
   Remove-Item "$env:TEMP\helium-profile.zip", "$HOME\Downloads\ublock-backup.txt"
   git add systems/x86_64-linux/orome/helium-profile.sops
   git commit -m "chore(orome): helium profile from windows"
   git push
   ```
3. On orome, start helium once so it makes its profile and installs the extensions, close it, then:
   ```sh
   cd ~/.config/net.imput.helium/Default && nix shell nixpkgs#unzip -c unzip -o /run/secrets/helium/profile
   ```
   And in uBlock's dashboard: settings, "restore from file", `~/.config/net.imput.helium/Default/ublock-backup.txt`.
   On the next start the tabs and groups are back, if not: history, recently closed.
   Should bitwarden ask to log in after all: "log in with device", approved from the phone, then set its timeout to never again.
4. Once that all works, remove `helium-profile.sops` from the repo, the secret goes with it.

## SSH keys

- `id_ulmo` is the personal key. Import it into bitwarden as an ssh key item, git signs commits through bitwarden's agent
  and every machine trusts this key. Add it to forgejo and github as ssh and signing key, and remove `id_rsa` from forgejo.
- `tv-woonkamer_webos`, `tv.ppk` and `webos_emul` (webos development on the tv) go to `~/.ssh`, `chmod 600`.
- Everything else in `.ssh` stays behind, the config and known hosts come from this repo.

## AWS

`~/.aws/config` comes from orome's secrets. Sign in with `aws sso login --sso-session menicon`, which covers every profile.

## Claude Code and Copilot

- `~/.claude/settings.json` and the own skills `~/.claude/skills/council-of-five` and `rubber-duck` go to the same place,
  plugins install again from their marketplace.
- The memories are in `~/.claude/projects/<path>/memory`, named after the path of the repo on windows (`F--Forgejo-sneeuwvlok`).
  Once a repo is cloned, move its memory to the folder for the new path (`-home-chris-...`).
- `~/.copilot/config.json` and `~/.copilot/skills/llm-council`.
