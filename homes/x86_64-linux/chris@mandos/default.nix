{osConfig, ...}: {
  home.stateVersion = osConfig.system.stateVersion;

  programs.git = {
    settings.user = {
      name = "Chris Kruining";
      email = "chris@kruining.eu";
    };
  };

  sneeuwvlok = {
    defaults = {
      shell = "zsh";
      terminal = "ghostty";
      browser = "zen";
      editor = "zed";
    };

    shell = {
      corePkgs.enable = true;
    };

    themes = {
      enable = true;
      theme = "everforest";
      polarity = "dark";
    };

    application = {
      bitwarden.enable = true;
      teamspeak.enable = true;
      steam.enable = true;
      zen.enable = true;
    };
  };
}
