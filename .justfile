@_default:
  just --list --list-submodules

[doc('Manage vars')]
mod vars '.just/vars.just'

[doc('Manage machines')]
mod machine '.just/machine.just'

[doc('Show information about project')]
@show:
  echo "show"