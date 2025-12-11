set unstable := true
set quiet := true

_default:
    just --list

[script]
list:
    cd .. && just vars get ulmo zitadel/users \
    | jq fromjson \
    | jq -r -C '
        include ".jq/table";
        include ".jq/format";

        to_entries
        | sort_by(.key)
        | map(
            (.key|to_title) + ":\n"
            + to_table(
                .value
                | to_entries
                | sort_by(.key)
                | map({username:.key} + .value)
            )
        )
        | join("\n\n┄┄┄\n\n")
    '
