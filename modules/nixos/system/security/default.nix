{...}: {
  flake.modules.nixos.sneeuwvlok.system.security = {
    config,
    namespace,
    inputs,
    ...
  }: let
    cfg = config.sneeuwvlok.system.security;
  in {
    options.sneeuwvlok.system.security = {};

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
  };
}
