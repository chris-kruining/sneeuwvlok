{ config, user, sensitive, lib, ... }: {
  networking.firewall.enable = true;

#  security.sudo.execWheelOnly = true;
#  security.auditd.enable = true;
#  security.audit.enable = !config.boot.isContainer;

  # PGP set up.
  programs.gnupg.agent.enable = true;
}
