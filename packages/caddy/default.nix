{caddy}:
# The hash is of the go modules of the plugins, it changes with every caddy or go in nixpkgs, `./fix-hash.sh` updates it
caddy.withPlugins {
  plugins = ["github.com/corazawaf/coraza-caddy/v2@v2.1.0"];
  hash = "sha256-CWVppGV3torJOnzEcea1yHz+fiBNzsIsRmJrlyS2rwk=";
}
