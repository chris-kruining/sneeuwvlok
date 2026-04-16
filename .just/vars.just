set unstable := true
set quiet := true

base_path := justfile_directory() + "/systems/x86_64-linux"

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

[doc('Get var by {key} from {machine}')]
get machine key:
    sops decrypt {{ base_path }}/{{ machine }}/secrets.yml | yq ".$(echo "{{ key }}" | sed -E 's/\//./g') // \"\""

[doc('Remove var by {key} for {machine}')]
remove machine key:
    sops unset {{ base_path }}/{{ machine }}/secrets.yml "$(printf '%s\n' '["{{ key }}"]' | sed -E 's#/#"]["#g; s/\["([0-9]+)"\]/[\1]/g')"

    git add {{ base_path }}/{{ machine }}/secrets.yml
    git commit -m 'chore(secrets): removed secret "{{ key }}" from machine "{{ machine }}"' -- {{ base_path }}/{{ machine }}/secrets.yml > /dev/null

    echo "Done"

[doc('Generate var values for {machine}')]
[script]
generate machine:
    for key in $(nix eval --apply 'builtins.attrNames' --json ..#nixosConfigurations.{{ machine }}.config.sops.secrets | jq -r '.[]'); do
        # Skip if we already have a value
        [ $(just vars get "{{ machine }}" "$key" | jq -r) ] && continue

        just vars _rotate "{{ machine }}" "$key"
    done

[doc('Regenerate var values for {machine}')]
[script]
_rotate machine key:
    # Exit if there's no script
    [ -f "{{ justfile_directory() }}/script/{{ key }}" ] || exit 0

    echo "Executing script for {{ key }}"
    just vars set "{{ machine }}" "{{ key }}" "$(cd -- "$(dirname "{{ justfile_directory() }}/script/{{ key }}")" && source "./$(basename "{{ key }}")")"

[script]
check:
    cd ..

    for machine in $(ls {{ base_path }}); do
         just vars _check "$machine"
    done

[no-exit-message]
[script]
_check machine:
    # If the default nix file is missing,
    # we can skip this folder as we are
    # missing the files used to compare
    # the defined vs the configured secrets
    if [ ! -f "{{ base_path }}/{{ machine }}/default.nix" ]; then
        printf "\r• %-8sskipped\n" "{{ machine }}"
        exit 0
    fi

    exec 3< <(jq -nr \
        --rawfile defined <(nix eval --json ..#nixosConfigurations.{{ machine }}.config.sops.secrets 2>/dev/null) \
        --rawfile configured <([ -f "{{ base_path }}/{{ machine }}/secrets.yml" ] && sops decrypt {{ base_path }}/{{ machine }}/secrets.yml | yq '.' || echo "{}") \
        '
            [ $configured | fromjson | paths(scalars) | join("/") ] as $conf
            | $defined
            | fromjson
            | map(.key | select(. | IN($conf[]) | not))
            | unique
            | .[]
        ')

    pid=$! # Process Id of the previous running command
    spin='⠇⠋⠙⠸⢰⣠⣄⡆'

    i=0
    while kill -0 $pid 2>/dev/null
    do
    i=$(( (i+1) %${#spin} ))
    printf "\r${spin:$i:1} %s" "{{ machine }}"
    sleep .1
    done

    mapfile -t missing <&3

    if (( ${#missing[@]} > 0 )); then
        printf '\r✗ %-8smissing %d secret(s):\n%s\n' "{{ machine }}" "${#missing[@]}" "$(printf -- '    %s\n' "${missing[@]}")"
        exit 1
    else
        printf "\r✓ %-8sup to date\n" "{{ machine }}"
    fi
