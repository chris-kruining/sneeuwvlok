{
  caddy,
  corazaCaddy,
}:
(caddy.withPlugins {
  plugins = ["github.com/corazawaf/coraza-caddy/v2@v2.1.0"];
  hash = "sha256-R8x1gYjQh8vwZXV1HEMJWm9hHZknGk7STwWgEpXNO0Q=";
}).overrideAttrs (old: {
  passthru =
    (old.passthru or {})
    // {
      pluginSources = {
        coraza-caddy = corazaCaddy;
      };
    };
})
