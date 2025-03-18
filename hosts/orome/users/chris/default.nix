{ ... }:
{
  # full_name = "Chris Kruining";
  # is_trusted = true;

  modules = {
    themes = {
      enable = true;
      theme = "everforest";
      polarity = "dark";
    };

    system.audio.enable = true;
    networking.enable = true;

    develop = {
      rust.enable = true;
      js.enable = true;
      dotnet.enable = true;
    };

    desktop = {
      plasma.enable = true;

      terminal = {
        default = "ghostty";
        ghostty.enable = true;
      };

      editors = {
        default = "zed";
        zed.enable = true;
        nvim.enable = true;
      };

      browsers = {
        default = "chromium";
        firefox.enable = true;
        chrome.enable = true;
      };
    };

    shell = {
      default = "zsh";
      corePkgs.enable = true;
    };
  };
}