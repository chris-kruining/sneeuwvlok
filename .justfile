@_default:
  just --list --list-submodules

[doc('Manage vars')]
mod vars '.just/vars.just'

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