{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.${namespace}.development.rust;
in {
  options.${namespace}.development.rust = {
    enable = mkEnableOption "Enable rust development tools";
  };

  config = mkIf cfg.enable {
    # Stable toolchain from the fenix overlay, projects pinning their own toolchain do that in their devshell
    home.packages = [
      (pkgs.fenix.stable.withComponents ["cargo" "clippy" "rust-src" "rustc" "rustfmt"])
      pkgs.rust-analyzer
      pkgs.bacon
    ];
  };
}
