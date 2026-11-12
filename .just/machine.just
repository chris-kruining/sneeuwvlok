@_default: list

[doc('List machines')]
@list:
    ls -1 ../systems/x86_64-linux/

[doc('Update target machine')]
[no-exit-message]
@update machine:
    echo "Checking vars"
    cd .. && just vars _check {{ machine }}
    echo ""
    just assert '-d "../systems/x86_64-linux/{{ machine }}"' "Machine {{ machine }} does not exist, must be one of: $(ls ../systems/x86_64-linux/ | sed ':a;N;$!ba;s/\n/, /g')"
    nixos-rebuild switch -L --sudo --target-host {{ machine }} --flake ..#{{ machine }} --log-format internal-json -v |& nom --json

[doc('Check if target machine builds')]
[no-exit-message]
@check machine:
    just assert '-d "../systems/x86_64-linux/{{ machine }}"' "Machine {{ machine }} does not exist, must be one of: $(ls ../systems/x86_64-linux/ | sed ':a;N;$!ba;s/\n/, /g')"
    nix build ..#nixosConfigurations.{{ machine }}.config.system.build.toplevel

[doc('Install {machine} on the machine that booted the installer (the one on the network, or $INSTALLER_HOST). This wipes its disk, all but a partition its config keeps')]
[no-exit-message]
[script]
install machine:
    set -euo pipefail
    root="{{ justfile_directory() }}"
    dir="$root/systems/x86_64-linux/{{ machine }}"
    [ -d "$dir" ] || { echo "Machine {{ machine }} does not exist, must be one of: $(ls "$root/systems/x86_64-linux" | tr '\n' ' ')"; exit 1; }

    # The installer to install on: $INSTALLER_HOST, or the installer on the network. With more than one, ask which
    if [ -n "${INSTALLER_HOST:-}" ]; then
        host="$INSTALLER_HOST"
    elif found=$(avahi-browse --resolve --parsable --terminate _ssh._tcp 2>/dev/null); then
        # Resolved lines: =;interface;protocol;name;type;domain;hostname;address;port;txt
        installers=$(awk -F';' '$1 == "=" && $3 == "IPv4" && $7 ~ /^installer(-[0-9]+)?\.local$/ { print $7, $8 }' <<< "$found" | sort -u)
        case $(grep -c . <<< "$installers" || true) in
            0) echo "No installer found on the network, boot one or set INSTALLER_HOST to the address on its screen"; exit 1 ;;
            1) host=$(cut -d' ' -f2 <<< "$installers") ;;
            *) host=$(gum choose --header "More than one installer, pick the one with {{ machine }}'s address on its screen" <<< "$installers" | cut -d' ' -f2) ;;
        esac
        [ -n "$host" ] || exit 1
    else
        # Without avahi's daemon (wsl) there is nothing to browse, only its name
        host=installer.local
    fi
    target="root@$host"

    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT

    # Everything it needs from the secrets, before anything is wiped
    users=$(ls "$root/homes/x86_64-linux" | sed -n 's/@{{ machine }}$//p')
    keyfiles=$(grep -ho 'passwordFile = "[^"]*"' "$dir"/*.nix | cut -d'"' -f2 | sort -u)
    secret() { [ -f "$dir/secrets.yml" ] && sops decrypt --extract "$1" "$dir/secrets.yml" 2>/dev/null; }
    for user in $users; do
        secret "[\"users\"][\"$user\"][\"password_hash\"]" > /dev/null || { echo "Set $user's password first: just vars set {{ machine }} users/$user/password_hash \"\$(mkpasswd)\""; exit 1; }
    done
    if [ -n "$keyfiles" ]; then
        (umask 077 && secret '["luks"]["passphrase"]' > "$tmp/luks") || { echo "Set the disk passphrase first: just vars set {{ machine }} luks/passphrase '...'"; exit 1; }
    fi

    # The installer makes a new host key every boot, compare it with the one on its screen and keep it for this install only
    ssh-keyscan -t ed25519 "$host" 2>/dev/null > "$tmp/known_hosts"
    [ -s "$tmp/known_hosts" ] || { echo "Can't reach the installer at $host"; exit 1; }
    ssh-keygen -lf "$tmp/known_hosts"
    gum confirm "Is this the fingerprint on the installer's screen?"
    ssh_options=(-o "UserKnownHostsFile=$tmp/known_hosts" -o StrictHostKeyChecking=yes)

    # A partition it keeps through the install (`keepPartition = "<partuuid>"` in its config), everything else on that disk goes
    keep=$(grep -ho 'keepPartition = "[^"]*"' "$dir"/*.nix | cut -d'"' -f2 | head -1 || true)
    check_keep() {
        ssh "${ssh_options[@]}" "$target" bash -s -- "$keep" "$ntfs3g" <<'EOF'
            set -euo pipefail
            PATH=$2/bin:$PATH
            part=/dev/disk/by-partuuid/$1
            [ -b "$part" ] || { echo "The partition to keep ($1) isn't on this machine" >&2; exit 1; }
            [ "$(blkid -o value -s TYPE "$part")" = ntfs ] || { echo "The partition to keep ($1) isn't ntfs" >&2; exit 1; }
            # 14 hibernated, 15 not unmounted cleanly: the files that are only in windows' memory would be lost
            ntfs-3g.probe --readwrite "$part" || {
                case $? in
                    14|15) echo "Windows didn't shut down cleanly: turn off fast startup (powercfg /h off) and shut windows down" >&2 ;;
                    *) echo "ntfs-3g.probe can't open the partition to keep" >&2 ;;
                esac
                exit 1
            }
            echo "/dev/$(lsblk -no PKNAME "$part")"
    EOF
    }

    if [ -n "$keep" ]; then
        # The installer only has the kernel's ntfs driver, the check whether windows shut down cleanly comes with ntfs-3g
        ntfs3g=$(nix build --no-link --print-out-paths "$root#nixosConfigurations.installer.pkgs.ntfs3g^out")
        NIX_SSHOPTS="${ssh_options[*]}" nix copy --to "ssh://$target" "$ntfs3g"
        disk=$(check_keep)
        grep -qs "device = \"$disk\"" "$dir"/*.nix || { echo "The partition to keep is on $disk, which isn't a disk in its disko config"; exit 1; }
        ssh "${ssh_options[@]}" "$target" lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTUUID "$disk"
        gum confirm --default=false "This deletes every partition on $disk except $keep and installs {{ machine }} next to it. Continue?"

        # The old signatures go as well: disko skips formatting where blkid still finds one, like windows' esp at the same offset
        ssh "${ssh_options[@]}" "$target" bash -s -- "$disk" "$keep" <<'EOF'
            set -euo pipefail
            for part in $(lsblk -lnpo NAME,TYPE "$1" | awk '$2 == "part" { print $1 }'); do
                [ "$(blkid -o value -s PARTUUID "$part")" = "$2" ] && continue
                wipefs -a "$part"
                sgdisk --delete="$(cat "/sys/class/block/${part##*/}/partition")" "$1"
            done
            partprobe "$1"
            udevadm settle
    EOF
    else
        gum confirm --default=false "This wipes the disk of the machine at $host and installs {{ machine }} on it. Continue?"
    fi

    args=(--flake "$root#{{ machine }}" --target-host "$target"
      --ssh-option "UserKnownHostsFile=$tmp/known_hosts" --ssh-option StrictHostKeyChecking=yes)

    # Its ssh host key, when the repo knows it: sops decrypts its secrets with it from the first boot, so no install without it
    if [ -f "$dir/ssh_host_ed25519_key.pub" ]; then
        key=$(secret '["ssh"]["host_ed25519_key"]') || { echo "Its host key isn't in its secrets (ssh/host_ed25519_key), it can't decrypt them without it"; exit 1; }
        install -d -m 755 "$tmp/extra/etc/ssh"
        # `$(...)` drops the closing newline, and openssh doesn't load a key without it
        (umask 077 && printf '%s\n' "$key" > "$tmp/extra/etc/ssh/ssh_host_ed25519_key")
        [ "$(ssh-keygen -y -f "$tmp/extra/etc/ssh/ssh_host_ed25519_key" | cut -d' ' -f1-2)" = "$(cut -d' ' -f1-2 "$dir/ssh_host_ed25519_key.pub")" ] \
            || { echo "The host key in its secrets doesn't load, or doesn't match ssh_host_ed25519_key.pub"; exit 1; }
        cp "$dir/ssh_host_ed25519_key.pub" "$tmp/extra/etc/ssh/"
        args+=(--extra-files "$tmp/extra")
    fi

    # The disk encryption passphrase from its secrets, for its disko layout
    for keyfile in $keyfiles; do
        args+=(--disk-encryption-keys "$keyfile" "$tmp/luks")
    done

    # Its hardware report, when it uses one. It has to be known to git before the flake is evaluated
    facter=()
    if grep -qs 'facter.json' "$dir/hardware.nix"; then
        touch "$dir/facter.json"
        git -C "$root" add --intent-to-add "$dir/facter.json"
        facter=(--generate-hardware-config nixos-facter "$dir/facter.json")
    fi

    if [ -n "$keep" ]; then
        # disko's format mode doesn't wipe but doesn't mount either, nixos-anywhere then installs into the installer's memory.
        # So create first, then mount and install
        nixos-anywhere "${args[@]}" "${facter[@]}" --phases disko --disko-mode format
        check_keep > /dev/null
        nixos-anywhere "${args[@]}" --phases disko,install --disko-mode mount
        check_keep > /dev/null
    else
        nixos-anywhere "${args[@]}" "${facter[@]}" --phases disko,install
    fi

    if [ -s "$dir/facter.json" ]; then
        git -C "$root" add "$dir/facter.json"
        git -C "$root" commit -m 'chore({{ machine }}): hardware report from the install' -- "$dir/facter.json" > /dev/null
    fi

    ssh "${ssh_options[@]}" "$target" reboot || true
    echo "{{ machine }} is installed and reboots"
