set unstable := true
set quiet := true

@_default: list

repo_path := replace(justfile_directory(), "\\", "/")
machine_base_path := repo_path + "/machines"

[doc('List machines')]
@list:
    ls -1 {{ machine_base_path }}

[doc('Compare deployed system on {machine} with the local config')]
[no-exit-message]
[script]
diff machine:
    just assert '-d "{{ machine_base_path }}/{{ machine }}"' "Machine {{ machine }} does not exist, must be one of: $(ls {{ machine_base_path }} | sed ':a;N;$!ba;s/\n/, /g')"

    echo "Resolving deployed system on {{ machine }}"
    deployed="$(ssh {{ machine }} readlink -f /run/current-system)"

    echo "Copying deployed system closure from {{ machine }}"
    nix copy --from "ssh-ng://{{ machine }}" "$deployed"

    echo "Building local config for {{ machine }}"
    local="$(nix build --no-link --print-out-paths "{{ repo_path }}#nixosConfigurations.{{ machine }}.config.system.build.toplevel")"

    nix run nixpkgs#nvd -- diff "$deployed" "$local"

[doc('Check if target machine builds')]
[no-exit-message]
@check machine:
    just assert '-d "{{ machine_base_path }}/{{ machine }}"' "Machine {{ machine }} does not exist, must be one of: $(ls {{ machine_base_path }} | sed ':a;N;$!ba;s/\n/, /g')"
    nix build "{{ repo_path }}#nixosConfigurations.{{ machine }}.config.system.build.toplevel"
