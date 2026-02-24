set unstable := true
set quiet := true

base_path := invocation_directory() / "systems/x86_64-linux"

_default:
    just --list vars

[doc('List all vars of {machine}')]
list machine:
    sops decrypt {{ base_path }}/{{ machine }}/secrets.yml

[doc('Edit all vars of {machine} in your editor')]
edit machine:
    sops edit {{ base_path }}/{{ machine }}/secrets.yml

[doc('Set var {value} by {key} for {machine}')]
@set machine key value:
    sops set {{ base_path }}/{{ machine }}/secrets.yml "$(printf '%s\n' '["{{ key }}"]' | sed -E 's#/#"]["#g; s/\["([0-9]+)"\]/[\1]/g')" "\"$(echo '{{ value }}' | sed 's/\"/\\\"/g')\""

    git add {{ base_path }}/{{ machine }}/secrets.yml
    git commit -m 'chore(secrets): set secret "{{ key }}" for machine "{{ machine }}"' -- {{ base_path }}/{{ machine }}/secrets.yml > /dev/null

    echo "Done"

[doc('Get var value by {key} of {machine}')]
get machine key:
    sops decrypt {{ base_path }}/{{ machine }}/secrets.yml | yq ".$(echo "{{ key }}" | sed -E 's/\//./g')"

[doc('Remove var by {key} for {machine}')]
remove machine key:
    sops unset {{ base_path }}/{{ machine }}/secrets.yml "$(printf '%s\n' '["{{ key }}"]' | sed -E 's#/#"]["#g; s/\["([0-9]+)"\]/[\1]/g')"

    git add {{ base_path }}/{{ machine }}/secrets.yml
    git commit -m 'chore(secrets): removed secret "{{ key }}" from machine "{{ machine }}"' -- {{ base_path }}/{{ machine }}/secrets.yml > /dev/null

    echo "Done"

[script]
check:
    for machine in $(ls {{ base_path }}); do
        [ -f "{{ base_path }}/$machine/secrets.yml" ] || continue
        [ -f "{{ base_path }}/$machine/default.nix" ] || continue

        echo "Processing $machine"

        mapfile -t missing < <(jq -nr \
            --rawfile defined <(nix eval --json --apply 'builtins.attrNames' ..#nixosConfigurations.$machine.config.sops.secrets 2>/dev/null) \
            --rawfile configured <(sops decrypt {{ base_path }}/$machine/secrets.yml | yq '.') \
            '
                $defined | fromjson as $def
                | $configured
                | fromjson
                | paths(scalars)
                | join("/")
                | select(. | IN($def[]) | not)
            ')

        if (( ${#missing[@]} > 0 )); then
            printf 'missing the following %d secret(s):\n%s\n\n' "${#missing[@]}" "$(printf -- '- %s\n' "${missing[@]}")"
        fi
    done
