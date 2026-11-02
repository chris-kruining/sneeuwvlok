{ lib, namespace, ... }:
let
  inherit (lib) mkDefault;
in
{
  options.${namespace}.system.time = {};

  config = {
    # Every machine is at home in the netherlands, schedules (the nightly build, updates) are in local time
    time.timeZone = mkDefault "Europe/Amsterdam";
  };
}
