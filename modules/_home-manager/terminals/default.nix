{ pkgs, config, ... }:
{
  fonts.fontconfig.enable = true;

  home.packages = [
    (pkgs.nerdfonts.override { fonts = [ "FiraCode" "DroidSansMono" ]; })
  ];

  home.sessionVariables._ZO_ECHO = "1";

  programs = {
    git = {
      enable = true;
      extraConfig = {
        push = { autoSetupRemote = true; };
        credential.helper = "${ pkgs.git.override { withLibsecret = true; } }/bin/git-credential-libsecret";
      };
    };
  
    zsh = {
      enable = true;
      autosuggestion.enable = true;
      enableCompletion = true;
      syntaxHighlighting.enable = true;

      history = {
        size = 10000;
        path = "${config.xdg.dataHome}/zsh/history";
      };

      oh-my-zsh = {
        enable = true;
        plugins = ["git" "docker-compose" "zoxide"];
      };

      plugins = [
        {
          name = "zsh-autosuggestion";
          src = pkgs.fetchFromGitHub {
            owner = "zsh-users";
            repo = "zsh-autosuggestions";
            rev = "v0.7.0";
            sha256 = "1g3pij5qn2j7v7jjac2a63lxd97mcsgw6xq6k5p7835q9fjiid98";
          };
        }
        {
          name = "zsh-completions";
          src = pkgs.fetchFromGitHub {
            owner = "zsh-users";
            repo = "zsh-completions";
            rev = "0.34.0";
            sha256 = "0jjgvzj3v31yibjmq50s80s3sqi4d91yin45pvn3fpnihcrinam9";
          };
        }
        {
          name = "zsh-syntax-highlighting";
          src = pkgs.fetchFromGitHub {
            owner = "zsh-users";
            repo = "zsh-syntax-highlighting";
            rev = "0.7.0";
            sha256 = "0s1z3whzwli5452h2yzjzzj27pf1hd45g223yv0v6hgrip9f853r";
          };
        }
      ];
    };

    bat.enable = true;
    zoxide.enable = true;
    fzf.enable = true;
    eza = {
      enable = true;
      enableZshIntegration = true;
    };

    starship = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        add_newline = true;
        format = "$username$hostname$nix_shell$git_branch$git_commit$git_state$git_status$directory$jobs$cmd_duration$character";
      
        username = {
          style_user = "blue bold";
          style_root = "red bold";
          format = "[$user]($style) ";
          disabled = false;
          show_always = true;
        };
        
        hostname = {
          ssh_only = false;
          ssh_symbol = "🌐 ";
          format = "on [$hostname](bold red) ";
          trim_at = ".local";
          disabled = false;
        };

        nix_shell = {
          symbol = " ";
          format = "[$symbol$name]($style) ";
          style = "bright-purple bold";
        };
        
        git_branch = {
          only_attached = true;
          format = "[$symbol$branch]($style) ";
          symbol = "שׂ";
          style = "bright-yellow bold";
        };
        
        git_commit = {
          only_detached = true;
          format = "[ﰖ$hash]($style) ";
          style = "bright-yellow bold";
        };
        
        git_state = {
          style = "bright-purple bold";
        };
        
        git_status = {
          style = "bright-green bold";
        };
        
        directory = {
          read_only = " ";
          truncation_length = 0;
        };
        
        cmd_duration = {
          format = "[$duration]($style) ";
          style = "bright-blue";
        };
        
        jobs = {
          style = "bright-green bold";
        };
        
        character = {
          success_symbol = "[\\$](bright-green bold)";
          error_symbol = "[\\$](bright-red bold)";
        };
      };
    };

  };
}

