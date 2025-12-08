_default:
    just --list --list-submodules

set unstable
set quiet

mod vars '.just/vars.just'
mod machine '.just/machine.just'

[doc('Show information about project')]
show:
    echo "show"

[doc('update the flake dependencies')]
update:
    nix flake update
    git commit -m 'chore: update dependencies' -- ./flake.lock > /dev/null
    echo "Done"

[doc('Rebase branch on main')]
rebase:
    git stash -q \
    && git fetch \
    && git rebase origin/main \
    && git stash pop -q

    echo "Done"

[doc('Introspection on flake output')]
select key:
    nix eval --json .#{{ key }} | jq .

#===============================================================================================
# Utils
# ===============================================================================================
[no-cd]
[no-exit-message]
[private]
assert condition message:
    [ {{ condition }} ] || { echo -e 1>&2 "\n\x1b[1;41m Error \x1b[0m {{ message }}\n"; exit 1; }
