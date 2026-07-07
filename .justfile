set unstable := true
set quiet := true

@_default:
  just --list --list-submodules

[doc('Manage vars')]
mod vars '.just/vars.just'

[doc('Manage machines')]
mod machine '.just/machine.just'



#===============================================================================================
# Utils
#===============================================================================================
[no-exit-message]
[no-cd]
[private]
@assert condition message:
  [ {{ condition }} ] || { echo -e 1>&2 "\n\x1b[1;41m Error \x1b[0m {{ message }}\n"; exit 1; }
