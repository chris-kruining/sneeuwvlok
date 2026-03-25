{ config, namespace, inputs, ... }:
let
  cfg = config.${namespace}.system.security;
in
{
  imports = [
    ./boot
    ./sops
    ./sudo
  ];

  options.${namespace}.system.security = {};

  config = {
    security = {
      acme.acceptTerms = true;
      polkit.enable = true;

      pam = {
        u2f = {
          enable = true;
          settings.cue = true;
        };
      };
    };

    programs.gnupg.agent.enable = true;
  };
}
