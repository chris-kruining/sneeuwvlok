set unstable := true
set quiet := true

base_path := justfile_directory() + "/systems/x86_64-linux"

_default:
    just --list vars

[doc('List the keys of all vars of {machine}')]
list machine:
    sops decrypt {{ base_path }}/{{ machine }}/secrets.yml | yq -r 'def tree($indent): to_entries[] | ($indent + .key), (.value | objects | tree($indent + "    ")); tree("")'

[doc('List all vars of {machine}, including their values')]
values machine:
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
    git commit -m 'chore(secrets): remove secret "{{ key }}" from machine "{{ machine }}"' -- {{ base_path }}/{{ machine }}/secrets.yml > /dev/null

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

[doc('Check every machine for missing vars')]
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

    # Prints the declared secrets that have no value, looked up the way sops-nix does it: in the secret's own
    # sopsFile, by its format. A binary, dotenv or ini secret (or an empty key) is the whole file, a yaml or json
    # one a "/"-separated path to a value in it
    find_missing() {
        set -euo pipefail

        local secrets file format output data
        secrets=$(nix eval --json "..#nixosConfigurations.{{ machine }}.config.sops.secrets" \
            --apply 'builtins.mapAttrs (_: s: { inherit (s) key format; file = toString s.sopsFile; })')

        # Each file is decrypted once, for all the secrets in it
        while IFS=$'\t' read -r file format; do
            case $format in
                yaml|json) output=json ;;
                *) output=binary ;;
            esac

            if ! data=$(sops decrypt --input-type "$format" --output-type "$output" "$file" 2>/dev/null); then
                data=false
            elif [ "$output" != json ]; then
                data=true
            fi

            jq -r --arg file "$file" --arg format "$format" --argjson data "$data" '
                to_entries[]
                | select(.value.file == $file and .value.format == $format)
                | select(
                    if $data == false then true
                    elif $data == true or .value.key == "" then false
                    else (.value.key | split("/")) as $path
                        | (try ($data | getpath($path)) catch null)
                        | type | IN("string", "number", "boolean") | not
                    end
                )
                | .key
            ' <<< "$secrets"
        done < <(jq -r '[.[] | [.file, .format]] | unique[] | @tsv' <<< "$secrets")
    }

    exec 3< <(find_missing)

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

    if ! wait $pid; then
        printf "\r✗ %-8scan't evaluate its config\n" "{{ machine }}"
        exit 1
    fi

    if (( ${#missing[@]} > 0 )); then
        printf '\r✗ %-8smissing %d secret(s):\n%s\n' "{{ machine }}" "${#missing[@]}" "$(printf -- '    %s\n' "${missing[@]}")"
        exit 1
    else
        printf "\r✓ %-8sup to date\n" "{{ machine }}"
    fi
