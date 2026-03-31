{
  self,
  pkgs,
  ...
}: {
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

  nixpkgs.hostPlatform = "x86_64-linux";

  environment.systemPackages = with pkgs; [
    azure-cli
    github-copilot-cli
  ];

  sneeuwvlok = {
    hardware.has = {
      bluetooth = true;
      audio = true;
    };

    services.authentication.himmelblau.enable = true;

    application = {
      steam.enable = true;
    };

    editor = {
      nano.enable = true;
    };
  };

  system.stateVersion = "23.11";
}
