
try-again:
    nix flake update amarth-customer-portal
    nix flake check --all-systems --show-trace

update machine:
    nixos-rebuild switch --use-remote-sudo --target-host {{ machine }} --flake .#{{ machine }}