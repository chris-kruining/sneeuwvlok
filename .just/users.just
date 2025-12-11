set unstable := true
set quiet := true

_default:
    just --list

[script]
list:
    cd .. && just vars get ulmo zitadel/users | jq -r -C '
        import ".jq/table" as table;
        import ".jq/format" as f;

        fromjson
        | to_entries
        | sort_by(.key)
        | map(
            (.key|f::to_title) + ":\n"
            + table::create(
                .value
                | to_entries
                | sort_by(.key)
                | map({username:.key} + .value)
            )
        )
        | join("\n\n┄┄┄\n\n")
    ';

[script]
add:
    exec 5>&1

    pad () { [ "$#" -gt 1 ] && [ -n "$2" ] && printf "%$2.${2#-}s" "$1"; }

    input() {
        local label=$1
        local value=$2

        local res=$(gum input --header "$label" --value "$value")
        echo -e "\e[2m$(pad "$label" -11)\e[0m$res" >&5
        echo $res
    }

    data=`cd .. && just vars get ulmo zitadel/users | jq 'fromjson'`

    # Gather inputs
    org=`
        jq -r 'to_entries | map(.key)[]' <<< "$data" \
        | gum choose --header 'Which organisation to save to?' --select-if-one
    `
    username=`input 'user name' 'new-user'`
    email=`input 'email' 'new.user@example.com'`
    first_name=`input 'first name' 'John'`
    last_name=`input 'last name' 'Doe'`

    user_exists=`jq --arg 'org' "$org" --arg 'username' "$username" '.[$org][$username]? | . != null' <<< "$data"`

    if [ "$user_exists" == "true" ]; then
        gum confirm 'User already exists, overwrite it?' --padding="1 1" || exit 0
    fi

    next=`
        jq \
        --arg 'org' "$org" \
        --arg 'username' "$username" \
        --arg 'email' "$email" \
        --arg 'first_name' "$first_name" \
        --arg 'last_name' "$last_name" \
        --compact-output \
        '.[$org] += { $username: { email: $email, firstName: $first_name, lastName: $last_name } }' \
        <<< $data
    `

    gum spin --title "saving..." -- echo "$(cd .. && just vars set ulmo 'zitadel/users' "$next")"

[script]
remove:
    data=`cd .. && just vars get ulmo zitadel/users | jq fromjson`

    # Gather inputs
    org=`
        jq -r 'to_entries | map(.key)[]' <<< "$data" \
        | gum choose --header 'Which organisation?' --select-if-one
    `
    user=`
        jq -r --arg org "$org" '.[$org] | to_entries | map(.key)[]' <<< "$data" \
        | gum choose --header 'Which user?' --select-if-one
    `

    next=`
        jq \
        --arg 'org' "$org" \
        --arg 'user' "$user" \
        --compact-output \
        'del(.[$org][$user])' \
        <<< $data
    `

    gum spin --title "saving..." -- echo "$(cd .. && just vars set ulmo 'zitadel/users' "$next")"
