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
