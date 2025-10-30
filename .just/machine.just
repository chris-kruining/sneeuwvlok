@_default: list

[doc('List machines')]
@list:
  ls -1 ../systems/x86_64-linux/

[doc('Update the target machine')]
@update machine:
  just assert '-d "../systems/x86_64-linux/{{ machine }}"' "Machine {{ machine }} does not exist, must be one of: $(ls ../systems/x86_64-linux/ | tr '\n' ' ')"
  nixos-rebuild switch --use-remote-sudo --target-host {{ machine }} --flake ..#{{ machine }}