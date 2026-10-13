---
name: sops-secret-files
description: How config files that contain secrets are set up in this repo, with sops-nix secrets and sops templates (`config.sops.placeholder`). Use whenever a service needs a secret in its configuration, an env file, a config file it reads or a file it also writes to itself.
---

# Files containing secrets

Secrets never go into the nix store, and they are never injected by a hand written script (sed, python, jq, ...). sops-nix already renders files with secrets in them at activation: `sops.templates`. Everything below is a variation on that.

Secrets themselves are declared as `sops.secrets."<service>/<name>"` and stored with the just recipes, see the `just-recipes` skill for the naming convention and how to set or generate values.

## Pick the simplest fitting option

### 1. The service reads the secret from a file: point it at the secret

When a service (or its nixpkgs module) has a `*File` option, or supports a file reference in its config, pass the secret's path directly, no template needed.

```nix
# modules/nixos/services/media/mydia
clientSecretFile = config.sops.secrets."mydia/oidc_secret".path;

# modules/nixos/services/observability/grafana, grafana's own $__file{} syntax
client_secret = "$__file{${config.sops.secrets."grafana/oidc_secret".path}}";
```

### 2. The secret has to be inside a file: a sops template

Write the file's content in nix, with `config.sops.placeholder."<key>"` where a secret goes. sops-nix replaces the placeholders at activation and writes the result to `config.sops.templates."<name>".path` (under `/run/secrets/rendered/`). Hand that path to the service.

```nix
sops = {
  secrets."synapse/oidc_secret" = {
    restartUnits = ["matrix-synapse.service"];
  };

  templates."synapse-oidc.yaml" = {
    owner = "matrix-synapse";
    restartUnits = ["matrix-synapse.service"];
    content = ''
      oidc_providers:
        - issuer: "https://auth.kruining.eu"
          client_id: '${config.sops.placeholder."synapse/oidc_id"}'
          client_secret: '${config.sops.placeholder."synapse/oidc_secret"}'
    '';
  };
};

services.matrix-synapse.extraConfigFiles = [config.sops.templates."synapse-oidc.yaml".path];
```

This works for any format: env files (`environmentFile`/`EnvironmentFile`), ini, yaml, tfvars (`servarr/config.tfvars`), xml, ... Name templates after the service and the file: `<service>/<file>`, e.g. `sabnzbd/config.ini`, `vaultwarden/config.env`.

Structured content can be generated instead of written out, a placeholder is just a string:

```nix
content = builtins.toJSON {
  endpoint = "https://auth.kruining.eu";
  secret = config.sops.placeholder."jellyfin/oidc_secret";
};
```

The placeholder is replaced by the raw value, nothing escapes it for the file's format. That is fine for the generated secrets in this repo (`script/.shared/pwgen` and the like), but keep it in mind for values with quotes, `<`, `&`, ...

### 3. The service also writes to the file: render a template and install it

Some applications keep their config in a file they rewrite themselves (qBittorrent, Jellyfin plugins, ...), so it can't be a read-only link to `/run/secrets/rendered`. Render it as a template and copy it into place with `install`, owned by the service, as `modules/nixos/services/media/servarr` does for qBittorrent:

```nix
system.activationScripts.qbittorrent-config = {
  deps = lib.optional (!config.sops.useSystemdActivation) "setupSecrets";
  text = ''
    install -Dm0600 -o ${config.services.qbittorrent.user} -g ${config.services.qbittorrent.group} \
      ${config.sops.templates."qbittorrent/qBittorrent.conf".path} \
      ${config.services.qbittorrent.profileDir}/qBittorrent/config/qBittorrent.conf
  '';
};
```

Nix owns the whole file this way, anything the application wrote into it is replaced on every activation. When the application keeps state in that file which has to survive, look for a way to keep that state out of the nix managed file, or check with the user before building anything that merges files.

## Template and secret options

- `owner` / `group`: whoever reads the file, both default to `root`. Set them on the secret too when the service reads the secret's path itself (option 1).
- `mode`: defaults to `0400`. Use e.g. `0440` when a group (`media`) has to read it.
- `restartUnits`: the units that read it, so they restart when the value changes. Put it on both the secret and the template.
- `key`: reuse a value stored under another key, e.g. `"vaultwarden/email".key = "email/chris_kruining_eu";`.
- `sops.placeholder."<key>"` only exists for keys declared in `sops.secrets`, and is only replaced inside `sops.templates.<name>.content`. Anywhere else it ends up as a literal placeholder string.

## OIDC client credentials: from zitadel, not sops

Zitadel generates each app's client id and secret, they are never stored in sops. The tofu-zitadel unit writes them to the app's `directory` (`/var/lib/zitadel/apps/<org>_<project>_<app>/`, readable by zitadel only):

- `client_id`, `client_secret`: the bare values
- `env`: `CLIENT_ID=`/`CLIENT_SECRET=`, the names can be changed with the app's `exportMap`
- any entry of the app's `files`, a config file rendered by tofu with the credentials in it

Services get them through systemd's `LoadCredential`, which copies them to `/run/credentials/<unit>/` for that unit only. In the service's module:

```nix
let
  oidc = config.${namespace}.services.authentication.zitadel.organization.nix.project.ulmo.application.grafana;
in {
  ${namespace}.services.authentication.zitadel.organization.nix.project.ulmo.application.grafana.restartUnits = ["grafana.service"];

  systemd.services.grafana.serviceConfig.LoadCredential = ["oidc_client_secret:${oidc.directory}/client_secret"];
  services.grafana.settings."auth.generic_oauth".client_secret = "$__file{/run/credentials/grafana.service/oidc_client_secret}";
}
```

- a service that reads the secret from a file: `client_secret` (grafana, mydia, whose module already uses `LoadCredential` for its `*File` options)
- a service that takes env vars: `env` as `EnvironmentFile`, systemd reads it as root (vaultwarden)
- a service that wants them in a config file: render it with `files` (synapse's `oidc.yaml`), and install it into place in `preStart` if the service also writes to it (jellyfin's `SSO-Auth.xml`)

`files` entries are functions of `{ clientId, clientSecret }` and their content is a tofu string, so a literal `${` has to be written as `$${`. Use the zitadel module's `issuer` instead of writing out its url.

`just zitadel rotate <machine> <app>` regenerates an app's id and secret on the machine itself, the values never leave it. A path unit per app restarts its `restartUnits` whenever tofu rewrites its files. A service with `LoadCredential` on these files can't start before tofu-zitadel has applied once, on a fresh machine.
