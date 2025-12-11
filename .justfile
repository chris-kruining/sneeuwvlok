@_default:
  just --list --list-submodules

[doc('Manage vars')]
mod vars '.just/vars.just'

[doc('Manage users')]
mod users '.just/users.just'

[doc('Manage machines')]
mod machine '.just/machine.just'

[doc('Show information about project')]
@show:
  echo "show"

[doc('update the flake dependencies')]
@update:
  nix flake update
  git commit -m 'chore: update dependencies' -- ./flake.lock > /dev/null
  echo "Done"

[doc('Introspection on flake output')]
@select key:
  nix eval --show-trace --json .#{{ key }} | jq .



#===============================================================================================
# Utils
#===============================================================================================
[no-exit-message]
[no-cd]
[private]
@assert condition message:
  [ {{ condition }} ] || { echo -e 1>&2 "\n\x1b[1;41m Error \x1b[0m {{ message }}\n"; exit 1; }
