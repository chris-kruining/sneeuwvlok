{pkgs, ...}: let
  # F: from windows, `just machine install` leaves this partition alone and installs next to it
  keepPartition = "7dba2672-f6e0-4657-af3e-a507d891bbc5";

  part = "/dev/disk/by-partuuid/${keepPartition}";
in {
  # A one off, until F: is moved over. The partition is gone afterwards, so it never runs again and this file can go
  systemd.services.windows-f = {
    description = "Move F: from windows into ~/F, then give its space to the root partition";
    wantedBy = ["multi-user.target"];
    after = ["local-fs.target"];
    unitConfig.ConditionPathExists = part;
    # Not oneshot: the copy takes a while and the boot shouldn't wait for it
    serviceConfig.Type = "exec";
    path = with pkgs; [rsync util-linux systemd];

    script = ''
      set -euo pipefail
      src=/run/windows-f
      dest=/home/chris/F
      excludes=(--exclude='/$RECYCLE.BIN' --exclude='/System Volume Information')

      mkdir -p "$src" "$dest"
      mount -t ntfs3 -o ro "${part}" "$src"
      trap 'umount "$src" 2>/dev/null || true' EXIT

      rsync -rlt --info=stats1 "''${excludes[@]}" "$src/" "$dest/"
      chown -R chris: "$dest"

      # Every file read again and compared by content, a single difference keeps F: and the next boot tries again
      diff=$(rsync -rlcn --out-format='%i %n' "''${excludes[@]}" "$src/" "$dest/")
      if [ -n "$diff" ]; then
        echo "$diff"
        echo "The copy in $dest differs from F:, F: is kept"
        exit 1
      fi
      umount "$src"

      # The disk is in use, so the table is written without rereading it and the kernel is told per partition
      number() { cat "/sys/class/block/$(basename "$(readlink -f "$1")")/partition"; }
      disk=/dev/$(lsblk -no PKNAME "${part}")
      f=$(number "${part}")
      root=$(number /dev/disk/by-partlabel/disk-main-luks)

      sfdisk --no-reread --delete "$disk" "$f"
      partx --delete --nr "$f" "$disk"
      # `+` is as large as possible, start, name and uuid stay as they are
      echo ', +' | sfdisk --no-reread -N "$root" "$disk"
      partx --update --nr "$root" "$disk"

      # luks2 maps the whole partition when it is opened, so on the next boot growfs grows / to it
      echo "F: is in $dest and its partition is gone, / grows into the free space on the next boot"
    '';
  };

  fileSystems."/".autoResize = true;
}
