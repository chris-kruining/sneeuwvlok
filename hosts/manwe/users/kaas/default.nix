{ ... }:
{
  user = {
    full_name = "KAAS";
    email = "kaas@kaas.kaas";
    is_trusted = false;
  };

  themes = {
    enable = true;
    theme = "everforest";
    polarity = "dark";
  };

  develop = {
    rust.enable = true;
    js.enable = true;
    dotnet.enable = true;
  };

  desktop = {
    plasma = {
      enable = true;
      # autoLogin = true;
    };

    applications = {
      email.enable = true;
    };

    terminal = {
      default = "ghostty";
      ghostty.enable = true;
    };

    editors = {
      default = "nvim";
      nvim.enable = true;
    };

    browsers = {
      default = "chromium";
      chrome.enable = true;
    };
  };

  shell = {
    default = "zsh";
  };
}
