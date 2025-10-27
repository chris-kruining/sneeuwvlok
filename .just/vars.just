base_path := invocation_directory() / "systems/x86_64-linux"
sops := "nix shell nixpkgs#sops --command sops"
yq := "nix shell nixpkgs#yq --command yq"

@_default:
  just --list

[doc('list all vars of the target machine')]
list machine:
  {{ sops }} decrypt {{ base_path }}/{{ machine }}/secrets.yml
  
@edit machine:
  {{ sops }} edit {{ base_path }}/{{ machine }}/secrets.yml
  
@set machine key value:
  {{ sops }} set {{ base_path }}/{{ machine }}/secrets.yml "$(printf '%s\n' '["{{ key }}"]' | sed -E 's#/#"]["#g; s/\["([0-9]+)"\]/[\1]/g')" '"{{ value }}"'

  git add {{ base_path }}/{{ machine }}/secrets.yml
  git commit -m 'ops(secrets): set secret "{{ key }}" for machine "{{ machine}}"' -- {{ base_path }}/{{ machine }}/secrets.yml > /dev/null

  echo "Done"
  
@get machine key:
  {{ sops }} decrypt {{ base_path }}/{{ machine }}/secrets.yml | {{ yq }} ".$(echo "{{ key }}" | sed -E 's/\//./g')"
  
@remove machine key:
  {{ sops }} unset {{ base_path }}/{{ machine }}/secrets.yml "$(printf '%s\n' '["{{ key }}"]' | sed -E 's#/#"]["#g; s/\["([0-9]+)"\]/[\1]/g')"

  git add {{ base_path }}/{{ machine }}/secrets.yml
  git commit -m 'ops(secrets): removed secret "{{ key }}" from machine "{{ machine}}"' -- {{ base_path }}/{{ machine }}/secrets.yml > /dev/null

  echo "Done"