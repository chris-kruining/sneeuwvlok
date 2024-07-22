{ pkgs, config, ... }:
{
  environment.systemPackages = with pkgs; [
    git
    gitkraken
    zsh
    bat
    zoxide
    eza
    starship
    alacritty
    zed-editor
    corepack_22
    bun
    nano
  ];

  users.defaultUserShell = pkgs.zsh;

  fonts = {
    fontconfig.enable = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk
      noto-fonts-emoji
      liberation_ttf
      fira-code
      fira-code-symbols
      mplus-outline-fonts.githubRelease
      dina-font
      proggyfonts
      (nerdfonts.override { fonts = [ "FiraCode" "DroidSansMono" ]; })
    ];
  };

  programs.zsh.enable = true;
  programs.starship.enable = true;

  programs.nano = {
    enable = true;
    syntaxHighlight = true;
    nanorc = ''
      set autoindent
      set jumpyscrolling
      set linenumbers
      set mouse
      set saveonexit
      set smarthome
      set tabstospaces
      set tabsize 2
    '';
  };
}
