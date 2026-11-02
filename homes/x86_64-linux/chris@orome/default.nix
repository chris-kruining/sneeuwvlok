{
  lib,
  pkgs,
  config,
  osConfig,
  ...
}: let
  # Repositories on my own forges get my own address, everything else is work
  personalRemotes = [
    "https://git.amarth.cloud/**"
    "ssh://forgejo@git.amarth.cloud/**"
    "forgejo@git.amarth.cloud:**"
    "https://git.kruining.eu/**"
    "ssh://forgejo@git.kruining.eu/**"
    "forgejo@git.kruining.eu:**"
    "https://github.com/chris-kruining/**"
    "git@github.com:chris-kruining/**"
  ];
in {
  home.stateVersion = osConfig.system.stateVersion;

  home.packages = with pkgs; [dbeaver-bin bruno];

  # Read only, `aws sso login` keeps its tokens in ~/.aws/sso/cache. Change profiles with `just vars edit orome`
  home.file.".aws/config".source = config.lib.file.mkOutOfStoreSymlink osConfig.sops.secrets."aws/config".path;

  # The connections from pgadmin, only when dbeaver has none yet: it rewrites these files itself
  home.activation.dbeaverConnections = lib.hm.dag.entryAfter ["writeBoundary"] (let
    secrets = osConfig.sops.secrets;
  in ''
    dir="$HOME/.local/share/DBeaverData/workspace6/General/.dbeaver"
    if [ ! -e "$dir/data-sources.json" ]; then
      run mkdir -p "$dir"
      run install -m600 ${secrets."dbeaver/data_sources".path} "$dir/data-sources.json"
      run ${pkgs.bash}/bin/bash -c 'umask 077 && ${pkgs.coreutils}/bin/base64 -d ${secrets."dbeaver/credentials".path} > "$1"' _ "$dir/credentials-config.json"
    fi
  '');

  programs.git = {
    settings.user = {
      name = "Chris Kruining";
      email = "c.kruining@4dotnet.nl";
    };

    includes =
      map (url: {
        condition = "hasconfig:remote.*.url:${url}";
        contents.user.email = "chris@kruining.eu";
      })
      personalRemotes;
  };

  # Work mail. Exchange online over EWS, thunderbird signs in itself (oauth in a window), the broker can't hand it a token.
  # Thunderbird has no exchange calendar or contacts, those are in outlook from the o365 launchers
  accounts.email.accounts."4dotnet" = {
    address = "c.kruining@4dotnet.nl";
    realName = "Chris Kruining";
    flavor = "outlook.office365.com-ews";
    thunderbird = {
      enable = true;
      profiles = [config.snowfallorg.user.name];
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
      go.enable = true;
      ai.enable = true;
    };

    application = {
      bitwarden.enable = true;
      helium.enable = true;
      onlyoffice.enable = true;
      thunderbird.enable = true;
      studio.enable = true;

      matrix = {
        enable = true;
        fractal.enable = false;
      };
    };

    shell.zsh.enable = true;
    terminal.ghostty.enable = true;

    editor = {
      zed.enable = true;
      nano.enable = true;
    };
  };
}
