{ osConfig, ... }:
{
  home.stateVersion = osConfig.system.stateVersion;

  programs.git = {
    userName = "Chris Kruining";
    userEmail = "chris@kruining.eu";
  };

  sneeuwvlok = {
    shell = {
      default = "zsh";
      corePkgs.enable = true;
    };

    themes = {
      enable = true;
      theme = "everforest";
      polarity = "dark";
    };
  };
}
