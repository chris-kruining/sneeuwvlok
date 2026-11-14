# The router's configuration, applied with `nix run .#udm -- apply` (`plan`, the default, only shows the differences).
# Only what is listed here is managed, every other setting stays as the udm has it
{
  host = "192.168.1.1";
  site = "default";

  # The udm's certificate is self signed (CN=unifi.local), so it is pinned by its public key instead. After the udm
  # gets a new certificate: echo | openssl s_client -connect 192.168.1.1:443 2>/dev/null | openssl x509 -pubkey -noout \
  #   | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | base64
  pinnedPublicKey = "sha256//L3VMVRSLO0eI8dyov52dfFEFdqgOU6xzg2FpwRXKX98=";

  # Objects of the udm's rest collections (`/proxy/network/api/s/<site>/rest/<collection>`), found by their name. Only
  # the fields set here are changed, objects are never created or removed
  rest = {
    networkconf.Default = {
      # The udm answers `<hostname>.arda` for every dhcp client
      domain_name = "arda";
    };
  };
}
