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
      browser = "helium";
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

    development = {
      rust.enable = true;
      javascript.enable = true;
      dotnet.enable = true;
    };

    application = {
      bitwarden.enable = true;
      helium.enable = true;
      onlyoffice.enable = true;
      signal.enable = true;
    };

    shell.zsh.enable = true;
    terminal.ghostty.enable = true;

    editor = {
      zed.enable = true;
      nano.enable = true;
    };
  };
}
