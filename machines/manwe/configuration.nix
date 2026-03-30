{
  self,
  lib,
  pkgs,
  ...
}: {
  _module.args = {
    pkgs = lib.mkForce (import self.inputs.nixpkgs {
      system = "x86_64-linux";

      overlays = with self.inputs; [
        fenix.overlays.default
        nix-minecraft.overlay
        flux.overlays.default
      ];

      config = {
        allowUnfree = true;

        permittedInsecurePackages = [
          # I think this is because of zen
          "qtwebengine-5.15.19"

          # For mautrix-signal, the matrix to signal bridge
          "olm-3.2.16"
        ];
      };
    });
  };

  imports = [
    ./disks.nix
    ./hardware.nix
    self.inputs.home-manager.nixosModules.home-manager
    self.inputs.himmelblau.nixosModules.himmelblau
    self.inputs.jovian.nixosModules.default
    self.inputs.mydia.nixosModules.default
    self.inputs.nix-minecraft.nixosModules.minecraft-servers
    self.inputs.nvf.nixosModules.default
    self.inputs.sops-nix.nixosModules.sops
    (self.inputs.import-tree ../../modules/nixos)
  ];

  system.activationScripts.remove-gtkrc.text = "rm -f /home/chris/.gtkrc-2.0";

  services.logrotate.checkConfig = false;

  environment.systemPackages = with pkgs; [beyond-all-reason openrct2];

  sneeuwvlok = {
    hardware.has = {
      gpu.amd = true;
      bluetooth = true;
      audio = true;
    };

    boot = {
      quiet = true;
      animated = true;
    };

    desktop.use = "plasma";

    application = {
      steam.enable = true;
    };

    editor = {
      nano.enable = true;
    };
  };

  services.displayManager.autoLogin = {
    enable = true;
    user = "chris";
  };

  system.stateVersion = "23.11";
}
