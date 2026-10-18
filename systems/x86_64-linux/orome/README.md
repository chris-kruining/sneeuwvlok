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
3. Install. The hardware report is written into the repo first, it has to be known to git before nix evaluates the flake:
   ```sh
   touch systems/x86_64-linux/orome/facter.json && git add --intent-to-add systems/x86_64-linux/orome/facter.json
   nix run nixpkgs#nixos-anywhere -- \
     --flake .#orome \
     --target-host root@<ip> \
     --phases disko,install \
     --generate-hardware-config nixos-facter systems/x86_64-linux/orome/facter.json \
     --disk-encryption-keys /tmp/secret.key /tmp/orome-luks
   rm /tmp/orome-luks
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
