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
    terminal = {
      default = "ghostty";
      ghostty.enable = true;
    };

    editors = {
      default = "nano";
      nano.enable = true;
    };
  };

  shell = {
    default = "zsh";
  };
}
