[private]
default: 
    @just -l

[doc('Update flake dependencies')]
update:
    nix flake update

[doc('install nixos on a system (uses nix-anywhere)
> profile: Which profile to use
> host: How to reach the target system in the standard format of `user@host`
')]
install profile host:
    nix run nixpkgs#nixos-anywhere -- \
    --flake .#{{profile}} \
    --generate-hardware-config nixos-generate-config ./hardware-configuration.nix \
    {{host}}

[doc('builds the configuration for the host')]
build host:
    nh os build . -H {{host}}

edit-secrets target:
    sops --config "{{justfile_directory()}}/.sops.yml" edit "{{justfile_directory()}}/{{ if target =~ ".+@.+" { "homes" } else { "systems" } }}/x86_64-linux/{{target}}/secrets.yaml"