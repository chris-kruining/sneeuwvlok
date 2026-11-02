{ config, namespace, inputs, ... }:
let
  cfg = config.${namespace}.system.security;
in
{
  options.${namespace}.system.security = {};

  config = {
    security = {
      acme.acceptTerms = true;
      polkit.enable = true;

      pam = {
        # TODO :: Turn this back on once a yubikey is registered (`pamu2fcfg > ~/.config/Yubico/u2f_keys`).
        #         It is `sufficient` in every pam service, so first decide where it may stand in for the password:
        #         not for sddm and login (`security.pam.services.<name>.u2fAuth = false`), the password there unlocks kwallet
        u2f = {
          enable = false;
          settings.cue = true;
        };
      };
    };

    programs.gnupg.agent.enable = true;
  };
}