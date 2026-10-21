# Description

My work laptop, reasoning for the name being the following chain of thought:  
**Orome -> the huntsman -> hunting means leaving home -> work laptop travels with me**

# Installing

With nixos-anywhere, from another machine that has nix and this repo (e.g. manwe). It wipes the disk and partitions it as `disks.nix` describes.

0. Turn secure boot off in the firmware (F1 at the lenovo logo), neither the installer nor the first boot are signed.
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

Log in as `chris` with the password from the install, then go down the list. Each step links to what it does, how to tell it worked
and what to do when it didn't.

- [ ] Secure boot: in the firmware (F1 at the lenovo logo), security, secure boot: reset to setup mode and turn secure boot on. Boot, then `sbctl status` ([explained](#secure-boot))
- [ ] Let the tpm unlock the disk: `sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-partlabel/disk-main-luks`, reboot ([explained](#tpm-unlock))
- [ ] Enroll a finger: `fprintd-enroll`, then `sudo true` with that finger ([explained](#fingerprint))
- [ ] Sign in to entra once: `sudo aad-tool auth-test --name c.kruining@4dotnet.nl`, set the hello pin ([explained](#entra))
- [ ] Personal key in bitwarden: import `id_ulmo` as ssh key item, then `ssh-add -L` ([explained](#personal-key))
- [ ] Helium: start it once, close it, unpack the bundle, restore uBlock ([explained](#helium-restore))
- [ ] Teams: open "Teams" from the o365 launchers, it signs in without a password ([explained](#teams-and-office))
- [ ] Thunderbird: open it, sign in to the 4dotnet account in its window ([explained](#thunderbird))
- [ ] AWS: `aws sso login --sso-session menicon`, then connect "Menicon" in the AWS VPN Client ([explained](#aws))
- [ ] Thuis vpn: on another network (phone hotspot) it connects by itself, `ping ulmo` ([explained](#thuis-vpn))
- [ ] Firmware: `fwupdmgr get-devices` and `fwupdmgr get-updates` ([explained](#firmware-updates))
- [ ] Updates: `systemctl list-timers nixos-upgrade` shows tomorrow 05:00 ([explained](#updates))
- [ ] Commit `facter.json`, and remove `helium-profile.sops` and `ublock-backup.mjs` from the repo ([explained](#cleaning-up))

## What the steps do

### Secure boot

Lanzaboote made its own secure boot keys on the first boot (`/var/lib/sbctl`). Setup mode clears the factory keys, so the firmware
accepts new ones without asking. On the next boot systemd-boot enrolls lanzaboote's keys, and microsoft's next to them because
firmware parts (option roms, of thunderbolt devices for example) are signed with those.

- Worked: `sbctl status` says `Secure Boot: enabled` and `Setup Mode: disabled`, and `sbctl verify` shows the boot files as signed.
- Still in setup mode: the keys weren't enrolled on that boot, lanzaboote's units in `journalctl -b` tell why.
  The firmware stays in setup mode until keys are enrolled, so a reboot tries again.
- Doesn't boot with secure boot on: turn it off in the firmware, boot, and check `sbctl verify`, something unsigned is on `/boot`.

### TPM unlock

Puts a second key on the luks partition, sealed in the tpm to PCR 7: the secure boot state and its keys. The tpm only hands it out
when secure boot is on with these keys, so a usb stick or other keys get the passphrase prompt instead. The passphrase stays.

- Worked: the reboot doesn't ask for the disk passphrase. `sudo systemd-cryptenroll /dev/disk/by-partlabel/disk-main-luks`
  lists a `password` and a `tpm2` slot.
- Still asks: check `sbctl status`, secure boot has to be on before enrolling. Wipe the tpm slot with
  `sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/disk/by-partlabel/disk-main-luks` and enroll again.
- After a firmware update it may ask once, PCR 7 can change. Enroll again like above.

### Fingerprint

fprintd stores the finger, pam uses it for sudo and the lockscreen. Logging in stays the password, that is what unlocks kwallet.

- Worked: `sudo true` asks for the finger and accepts it, `fprintd-list chris` shows the finger.
- No reader found: `fprintd-list chris` errors, check `lsusb | grep 06cb:00f9`.

### Entra

Signs in to entra once as `c.kruining@4dotnet.nl`, which `chris` is mapped to. It registers the device in the tenant, sets the hello
pin (kept in the tpm) and gives the broker its token, apps get theirs from the broker. After a reboot the broker asks for the pin
once, the first time an app wants a token.

- Worked: `aad-tool auth-test` ends successfully.
- Fails: `journalctl -u himmelblaud`, the tenant may have to allow the device to join.

### Personal key

The personal key signs commits (git asks the ssh agent, which is bitwarden's) and is trusted for root and chris on every machine.

- Worked: `ssh-add -L` shows `...1Taj chris`, a commit shows `Good "git" signature` in `git log --show-signature`, `ssh ulmo` works.
- `ssh-add -L` says there is no agent: the bitwarden desktop app has to run, with its ssh agent turned on in its settings.

### Helium restore

The bundle holds the extensions' settings and the open tabs and groups. Helium has to have made its profile and installed the
extensions first, so they find their settings back.

```sh
cd ~/.config/net.imput.helium/Default && nix shell nixpkgs#unzip -c unzip -o /run/secrets/helium/profile
```

Then in uBlock's dashboard: settings, "restore from file", `~/.config/net.imput.helium/Default/ublock-backup.txt`.

- Worked: the tabs and groups are back (else history, recently closed), bitwarden is unlocked, the extensions keep their settings.
- `/run/secrets/helium/profile` is missing: `helium-profile.sops` wasn't in the repo when orome was built.
- Bitwarden asks to log in: "log in with device", approved from the phone, then its timeout back to never.

### Teams and office

The o365 launchers are teams-for-linux in intune mode, which gets its token from himmelblau's broker instead of asking.

- Worked: Teams opens signed in. Outlook, word and the others are web apps from the same launchers.
- Asks to sign in: the entra step didn't finish, or the broker wants the pin, check `journalctl --user -u himmelblau-broker`.

### Thunderbird

The work account is configured (exchange over ews), thunderbird signs in itself in a window, the broker can't hand it a token.
It has no exchange calendar or contacts, those are in outlook.

- Worked: mail comes in after signing in.
- Fails right away: ews may be off for the tenant, add the account in thunderbird's own account setup instead, it offers microsoft graph.

### AWS

`~/.aws/config` comes from orome's secrets, one sso session for every profile. The AWS VPN Client is the official one, its daemon
runs as `aws-client-vpn-daemon.service`. This is its first real test on orome.

- Worked: `aws sts get-caller-identity --profile development` answers, the vpn connects after the browser login.
- VPN fails: `journalctl -u aws-client-vpn-daemon` and `/var/log/awsvpnclient`. Import the profile again if it's missing.

### Thuis VPN

A networkmanager profile, a dispatcher script brings it up on any network that isn't `Varkensstal` once there's full connectivity.

- Worked: `nmcli connection show --active` lists `Thuis` away from home, `ping ulmo` answers.
- Doesn't come up: `nmcli connection up Thuis` by hand, and `journalctl -u NetworkManager-dispatcher`.

### Firmware updates

fwupd gets firmware from LVFS, lanzaboote signs fwupd's uefi updater with its own key so it boots with secure boot on.

- Worked: `get-devices` lists the system firmware, `get-updates` either offers an update or says there is none.
- `fwupd-efi.service` failed: on the very first boot the keys didn't exist yet, `sudo systemctl restart fwupd` fixes it.
- No system firmware listed: lenovo doesn't publish this model on LVFS, the bios then updates with lenovo's bootable image.

### Updates

Every day at 05:00 (or right after booting, when it was off) orome takes main from ulmo's nightly build, for the next boot, and says
so in a notification. It never builds anything itself.

- Worked: the timer is listed, `journalctl -u nixos-upgrade` shows the runs.
- Fails: away from home without the Thuis vpn the cache isn't reachable, it tries again later.

### Cleaning up

`facter.json` is the hardware report the install wrote into the repo. The helium bundle holds bitwarden's vault key, so it goes once
it's been used, `ublock-backup.mjs` with it.

# Moving over from Windows

## Helium

Its extensions install themselves from the web store on the first start, bitwarden gets its server (`vault.kruining.eu`) through
policy, the rest have no managed storage. Their settings and the open tabs and tab groups come along in a bundle that is encrypted
for orome (`helium-profile.sops`, like `secrets.yml`), sops-nix decrypts it to `/run/secrets/helium/profile`. It also holds
bitwarden's vault key, that is how it arrives unlocked without the master password. Cookies and saved passwords don't come along,
windows encrypted those for that machine. uBlock's own storage is mostly its cache, only its backup file comes along.

1. On windows, right before the wipe, close helium completely (on windows its processes are called `chrome.exe`), then from this repo
   (PowerShell). It also makes uBlock's backup, through a headless helium on the real profile, and commits and pushes the bundle:
   ```powershell
   $ud = "$env:LOCALAPPDATA\imput\Helium\User Data"
   $p = "$ud\Default"
   $ublock = "blockjmkbacgjkknlgpkjjiijinjdanf"
   $t = New-Item -ItemType Directory "$env:TEMP\helium-profile" -Force

   $h = Start-Process "$env:LOCALAPPDATA\imput\Helium\Application\chrome.exe" -PassThru -ArgumentList "--headless=new", "--remote-debugging-port=9333", "--user-data-dir=`"$ud`"", "--no-first-run", "about:blank"
   node systems/x86_64-linux/orome/ublock-backup.mjs "$t\ublock-backup.txt"
   Stop-Process -Id $h.Id
   Start-Sleep 3

   Copy-Item "$p\Sessions" $t -Recurse
   foreach ($d in "Local Extension Settings", "Sync Extension Settings") {
     Copy-Item "$p\$d" $t -Recurse
     Remove-Item "$t\$d\$ublock" -Recurse -Force -ErrorAction SilentlyContinue
   }
   New-Item -ItemType Directory "$t\IndexedDB" -Force | Out-Null
   Get-ChildItem "$p\IndexedDB" -Directory -Filter "chrome-extension_*" | Where-Object Name -notlike "*$ublock*" | Copy-Item -Destination "$t\IndexedDB" -Recurse
   Compress-Archive "$t\*" "$env:TEMP\helium-profile.zip" -Force
   Remove-Item $t -Recurse -Force

   wsl -d NixOS -- bash -lc 'cd /mnt/f/Forgejo/sneeuwvlok && nix develop -c sops encrypt --filename-override systems/x86_64-linux/orome/helium-profile.sops --input-type binary --output-type binary /mnt/c/Users/ChrisKruining/AppData/Local/Temp/helium-profile.zip > systems/x86_64-linux/orome/helium-profile.sops'
   Remove-Item "$env:TEMP\helium-profile.zip"
   git add systems/x86_64-linux/orome/helium-profile.sops
   git commit -m "chore(orome): helium profile from windows"
   git push
   ```
2. On orome it's restored from the first boot list, [helium restore](#helium-restore).

## SSH keys

- `id_ulmo` is the personal key. Import it into bitwarden as an ssh key item, git signs commits through bitwarden's agent
  and every machine trusts this key. Add it to forgejo and github as ssh and signing key, and remove `id_rsa` from forgejo.
- `tv-woonkamer_webos`, `tv.ppk` and `webos_emul` (webos development on the tv) go to `~/.ssh`, `chmod 600`.
- Everything else in `.ssh` stays behind, the config and known hosts come from this repo.

## AWS

`~/.aws/config` comes from orome's secrets. Sign in with `aws sso login --sso-session menicon`, which covers every profile.

## Claude Code and Copilot

Skills, settings and plugins come from this repo (`modules/home/development/ai`). Only the memories come over by hand:
they are in `~/.claude/projects/<path>/memory`, named after the path of the repo on windows (`F--Forgejo-sneeuwvlok`).
Once a repo is cloned, move its memory to the folder for the new path (`-home-chris-...`).
