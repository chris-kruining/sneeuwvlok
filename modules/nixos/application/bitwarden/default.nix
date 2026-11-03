{
  config,
  pkgs,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.application.bitwarden;
in {
  options.${namespace}.application.bitwarden = {
    enable = mkEnableOption "enable bitwarden";
  };

  config = mkIf cfg.enable {
    # The home-manager package alone isn't enough for "unlock with system authentication": it ships its own
    # polkit policy (share/polkit-1/actions/com.bitwarden.Bitwarden.policy), but polkit only scans the system
    # profile for actions, not a per-user home-manager profile. Putting it in systemPackages too (same store
    # path, no extra disk use) is enough for that file to show up where polkit looks.
    environment.systemPackages = [pkgs.bitwarden-desktop];
  };
}
