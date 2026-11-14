{
  pkgs,
  inputs,
  namespace,
  ...
}: let
  testPkgs = pkgs.extend (_: prev: {
    wakeonlan = prev.writeShellScriptBin "wakeonlan" ''
      printf '%s\n' "$*" >> "$WAKE_LOG"
    '';
  });
  machine = inputs.nixpkgs.lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    specialArgs = {inherit namespace;};
    modules = [
      ../../modules/nixos/services/development/llama-swap
      {
        nixpkgs.pkgs = testPkgs;
        ${namespace}.services.development.llama-swap = {
          enable = true;
          host = "127.0.0.1";
          upstreamPort = 18081;
          macAddress = "02:00:00:00:00:01";
          broadcastAddress = "127.0.0.1";
          models = ["test/model"];
          wakeTimeout = 15;
        };
      }
    ];
  };
  settings = pkgs.writeText "llama-swap-test.json" (builtins.toJSON machine.config.services.llama-swap.settings);
in
  pkgs.runCommand "llama-swap-test" {
    nativeBuildInputs = [pkgs.python3 pkgs.llama-swap];
  } ''
    python3 ${./test.py} ${settings}
    touch "$out"
  ''
