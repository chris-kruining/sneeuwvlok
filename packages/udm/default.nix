{
  writeShellApplication,
  writeText,
  curl,
  jq,
  sops,
}:
# Brings the udm in line with ./config.nix, on demand from any machine with the admin age key: `nix run .#udm [-- apply]`
writeShellApplication {
  name = "udm";
  runtimeInputs = [curl jq sops];

  runtimeEnv = {
    UDM_CONFIG = writeText "udm.json" (builtins.toJSON (import ./config.nix));
    # Holds `unifi/api_key`, encrypted to the admin key too
    UDM_SECRETS = ../../systems/x86_64-linux/orome/secrets.yml;
  };

  text = builtins.readFile ./udm.sh;
}
