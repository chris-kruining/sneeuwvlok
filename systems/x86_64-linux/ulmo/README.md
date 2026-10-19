# Description

My home server.

# Host key

ulmo's ssh host key is also what sops decrypts its secrets with. The private key is in `secrets.yml` (`ssh/host_ed25519_key`),
the public key is `ssh_host_ed25519_key.pub`, which every machine trusts as ulmo.

## Switching to the new host key

Until 2026-10 ulmo's host key was chris' personal ssh key. `secrets.yml` is encrypted to both that key and the new one (`ulmo_previous`
and `ulmo` in `.sops.yaml`) until this is done. From the devshell, steps 1 to 3 in one go: in between, the config that is running only
knows the old key, and a reboot would leave ulmo without its secrets.

1. Put the new host key in place, the old one stays next to it until the end:
   ```sh
   just vars get ulmo ssh/host_ed25519_key | jq -j -r . | ssh ulmo 'umask 077 && cat > /etc/ssh/ssh_host_ed25519_key.new'
   ssh ulmo 'cd /etc/ssh && mv ssh_host_ed25519_key ssh_host_ed25519_key.previous && mv ssh_host_ed25519_key.new ssh_host_ed25519_key && ssh-keygen -y -f ssh_host_ed25519_key > ssh_host_ed25519_key.pub && systemctl reload sshd'
   ```
2. On a machine that doesn't get its known hosts from this flake (windows, wsl), trust the new key. It has to match `ssh_host_ed25519_key.pub`:
   ```sh
   ssh-keygen -R ulmo
   ssh-keyscan -t ed25519 ulmo
   ```
3. Deploy, then check that the secrets are there and nothing failed:
   ```sh
   just machine update ulmo
   ssh ulmo 'ls /run/secrets && systemctl --failed'
   ```
4. Remove the old key, from ulmo and as a recipient:
   ```sh
   ssh ulmo 'rm /etc/ssh/ssh_host_ed25519_key.previous /etc/ssh/ssh_host_ed25519_key.back'
   ```
   Then delete `ulmo_previous` from `.sops.yaml`, run `sops updatekeys systems/x86_64-linux/ulmo/secrets.yml` and commit.
   The old key's age key can go from your keyring as well.
