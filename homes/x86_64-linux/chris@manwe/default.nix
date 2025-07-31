{ osConfig, ... }:
{
  home.stateVersion = osConfig.system.stateVersion;

  programs.git = {
    userName = "Chris Kruining";
    userEmail = "chris@kruining.eu";
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

    development = {
      rust.enable = true;
      javascript.enable = true;
      dotnet.enable = true;
    };

    application = {
      bitwarden.enable = true;
      discord.enable = true;
      ladybird.enable = true;
      obs.enable = true;
      onlyoffice.enable = true;
      signal.enable = true;
      steam.enable = true;
      studio.enable = true;
      teamspeak.enable = true;
      thunderbird.enable = true;
      zen.enable = true;
    };

    shell.zsh.enable = true;
    terminal.ghostty.enable = true;

    editor = {
      zed.enable = true;
      nvim.enable = true;
      nano.enable = true;
    };
  };
}
