{ inputs, lib, config, ... }: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.modules.desktop.gaming;
in
{
  imports = [ inputs.jovian.nixosModules.default ];

  options.modules.desktop.gaming = {
    enable = mkEnableOption "enable steamdeck like desktop";
  };

  config = mkIf cfg.enable {
    jovian.steam = {
      enable = true;
      autoStart = true;

    };
  };
}
