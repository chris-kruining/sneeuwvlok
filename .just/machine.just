@_default: list

[doc('List machines')]
@list:
  ls -1 ../systems/x86_64-linux/

[doc('Update the target machine')]
update machine:
  nixos-rebuild switch --use-remote-sudo --target-host {{ machine }} --flake ..#{{ machine }}