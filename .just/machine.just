@_default: list

[doc('List machines')]
@list:
    ls -1 ../systems/x86_64-linux/

[doc('Update the target machine')]
[no-exit-message]
@update machine:
    just assert '-d "../systems/x86_64-linux/{{ machine }}"' "Machine {{ machine }} does not exist, must be one of: $(ls ../systems/x86_64-linux/ | sed ':a;N;$!ba;s/\n/, /g')"
    nixos-rebuild switch --use-remote-sudo --target-host {{ machine }} --flake ..#{{ machine }}
