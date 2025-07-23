{ ... }:
{
  user = {
    full_name = "Chris Kruining";
    email = "chris@kruining.eu";
    is_trusted = true;
  };

  themes = {
    enable = true;
    theme = "everforest";
    polarity = "dark";
  };

  desktop = {
    plasma = {
      enable = true;
      autoLogin = true;
    };

    applications = {
      steam.enable = true;
    };

    terminal = {
      default = "ghostty";
      ghostty.enable = true;
    };

    editors = {
      default = "nano";
      nano.enable = true;
    };

    browsers = {
      default = "chromium";
      chrome.enable = true;
      ladybird.enable = true;
    };
  };

  shell = {
    default = "zsh";
  };
}
