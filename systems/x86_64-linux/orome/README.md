# Description

My work laptop, reasoning for the name being the following chain of thought:  
**Orome -> the huntsman -> hunting means leaving home -> work laptop travels with me**

# Installing

From a NixOS installer, with this repo cloned:

1. Wipe and partition the disk, the config finds everything by label. Check with `lsblk` that `nvme0n1` is the KIOXIA first.
   The ESP is 1 GiB because grub copies every kernel generation onto it:
   ```sh
   parted /dev/nvme0n1 -- mklabel gpt
   parted /dev/nvme0n1 -- mkpart boot fat32 1MiB 1GiB
   parted /dev/nvme0n1 -- set 1 esp on
   parted /dev/nvme0n1 -- mkpart root 1GiB 100%
   mkfs.fat -F 32 -n boot /dev/nvme0n1p1
   cryptsetup luksFormat --label cryptroot /dev/nvme0n1p2
   cryptsetup open /dev/disk/by-label/cryptroot cryptroot
   mkfs.ext4 -L nixos /dev/mapper/cryptroot
   mount /dev/disk/by-label/nixos /mnt
   mount --mkdir -o fmask=0077,dmask=0077 /dev/disk/by-label/boot /mnt/boot
   ```
2. Generate the hardware report and commit it, orome does not build without it:
   ```sh
   sudo nix run nixpkgs#nixos-facter -- -o systems/x86_64-linux/orome/facter.json
   ```
3. Install, this asks for the root password at the end:
   ```sh
   sudo nixos-install --flake .#orome
   ```
4. Give `chris` a password before rebooting, nothing declares one and it is the way in when himmelblau is not working:
   ```sh
   sudo nixos-enter --root /mnt -c 'passwd chris'
   ```

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
