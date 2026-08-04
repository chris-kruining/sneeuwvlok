## Context

The current Clan service modules are converging on a common shape: `default.nix` declares the Clan service manifest, role interface, exports, and NixOS module fragments. For simple services this is readable, but driver-backed services are starting to mix generic service wiring with concrete driver interface, export, and NixOS implementation details.

The communications service currently contains Matrix-specific helpers, Matrix exports, Synapse settings, LiveKit, TURN, and bridge setup in one file. The identity service is a better reference point because Zitadel reconciliation logic is partially isolated in `lib.nix`, but its driver-specific NixOS configuration still lives inline inside a `mkIf` fragment. The desired next step is a reusable driver-file convention that can apply to communications first and then later to identity, version-control, media, observability, backup, persistence, and network roles where appropriate.

There are currently two ways service modules receive shared helpers. Services registered through `clan.modules` can receive `clan.specialArgs.ardaLib` from `clan/flake-module.nix`, while some services such as media and version-control currently construct a local `ardaLib` in their service-specific `flake-module.nix`. This change applies the helper first to communications through `clan.specialArgs.ardaLib` and must verify that path explicitly. Making the helper available to locally injected services is a follow-up template-alignment concern.

## Goals / Non-Goals

**Goals:**

- Keep each service `default.nix` focused on service manifest, driver discovery, shared interface assembly, role wiring, common fragments, and dispatch.
- Move driver-specific interface, exports, and NixOS module bodies into `drivers/<driver>.nix`.
- Make driver files role-aware by exposing role-named behavior under `roles`, such as `roles.default`.
- Add shared helpers that return selected driver export and NixOS module fragments as lists for appending into `mkMerge`.
- Wire that helper through the `clan.specialArgs.ardaLib` path used by path-registered Clan services and verify communications can resolve it.
- Fail with clear, intentional errors when a configured driver or role is missing.
- Use communications and its Matrix driver as the first concrete application of the template.

**Non-Goals:**

- Do not change Matrix runtime behavior as part of this refactor.
- Do not immediately refactor every Clan service in the repository.
- Do not remove `mkMerge`-based composition from services; common non-driver fragments must remain easy to combine with selected driver fragments.
- Do not solve all existing cross-service coupling in this change; note the Arrtrix/Servarr coupling for a later explicit-composition cleanup.
- Do not normalize every existing `ardaLib` provisioning path in this change.

## Decisions

### Driver files own interface and role behavior

Driver files SHALL expose a driver-specific `interface` and an attrset of role behavior keyed by role name:

```nix
{lib, ...}: {
  interface = lib.types.submodule {
    options = {
      # driver-specific settings
    };
  };

  roles.default = {
    exports = roleArgs: [
      # export fragments for mkMerge
    ];

    nixosModules = roleArgs: moduleArgs: [
      # NixOS module body fragments for mkMerge
    ];
  };
}
```

This keeps all driver-specific details colocated: the accepted settings type, the exports produced by a role, and the NixOS module fragments produced by that role. Service `default.nix` remains the wiring layer and keeps service manifest, driver discovery, shared/common options, common fragments, and dispatch.

For the identity service, `drivers/zitadel.nix.roles.default.nixosModules` would contain a lift-and-shift of the contents currently inside the `mkIf (settings.driver == "zitadel")` fragment inside the `mkMerge` list. Its `roles.default.exports` would contain the Zitadel-specific export fragments currently gated by `settings.driver == "zitadel"`, while service-wide common exports can remain in `default.nix`.

Alternative considered: driver files returning only role NixOS module body functions. This was rejected because driver-specific exports would remain in service `default.nix`, leaving an important part of driver behavior separated from the rest of the driver.

Driver file top-level evaluation MUST remain interface-safe. The top level may depend on `lib` and other explicitly injected pure helper arguments, but it MUST NOT read NixOS `config`, role `settings`, `pkgs`, or per-instance values. Those values are only available inside `roles.<roleName>.exports roleArgs` and `roles.<roleName>.nixosModules roleArgs moduleArgs`.

### `default.nix` owns driver and role dispatch

Each service `default.nix` SHALL discover/import its drivers and select the configured driver plus current role. It remains responsible for the Clan service manifest, role definitions, shared interface assembly, common export/NixOS fragments, and merge-friendly dispatch.

Example shape:

```nix
let
  drivers = ardaLib.clanServices.discoverDrivers {
    dir = ./drivers;
    inherit lib;
  };
  driverInterfaces = drivers |> lib.mapAttrs (_: driver: driver.interface);
in {
  roles.default.perInstance = args@{ settings, ... }: let
    fragments = ardaLib.clanServices.driverRoleFragments {
      serviceName = "communications";
      inherit drivers;
      driver = settings.driver;
      roleName = "default";
      roleArgs = args;
    };
  in {
    exports = mkExports (mkMerge (
      commonExportFragments
      ++ fragments.exports
    ));

    nixosModule = moduleArgs: {
      config = mkMerge (
        commonNixosFragments
        ++ fragments.nixosModules moduleArgs
      );
    };
  };

  roles.default.interface = {
    options = {
      driver = mkOption {
        type = types.enum (drivers |> lib.attrNames);
        default = "matrix";
      };
      settings = mkOption {
        type = types.oneOf (driverInterfaces |> lib.attrValues);
      };
      # shared service options stay here
    };
  };
}
```

### Shared helper is exposed through `ardaLib.clanServices`

The helpers SHALL live in shared repo lib code and be made available through `clan/flake-module.nix` for path-registered Clan services. Communications must add `ardaLib` to its `default.nix` argument set and use that helper path.

`discoverDrivers` SHALL import and apply each discovered driver file with the pure arguments it receives:

```nix
discoverDrivers {
  dir = ./drivers;
  inherit lib;
}
```

This returns evaluated driver attrsets whose `interface` values can be used while assembling the service interface.

Services that currently construct their own local `ardaLib` in service-specific `flake-module.nix` will not automatically receive these helpers unless those local attrsets are also extended. That broader alignment is not required to refactor communications but must be noted when applying the template to those services later.

### Shared helper returns fragments for `mkMerge`

Services must keep `mkMerge` as the composition point so common non-driver fragments can be combined with selected driver fragments. The helper returns normalized fragment lists:

```nix
driverRoleFragments {
  serviceName = "communications";
  inherit drivers;
  driver = settings.driver;
  roleName = "default";
  roleArgs = args;
}
```

returns:

```nix
{
  exports = selectedRole.exports roleArgs;
  nixosModules = moduleArgs: selectedRole.nixosModules roleArgs moduleArgs;
}
```

The service then composes:

```nix
exports = mkExports (mkMerge (
  commonExportFragments
  ++ fragments.exports
));

nixosModule = moduleArgs: {
  config = mkMerge (
    commonNixosFragments
    ++ fragments.nixosModules moduleArgs
  );
};
```

### Driver discovery is allowed

Because each driver file exposes the same top-level shape, services may auto-discover drivers from `./drivers`:

```nix
drivers = ardaLib.clanServices.discoverDrivers ./drivers;
```

The discovery helper should load regular `.nix` files, apply each file with the supplied pure arguments, and name each driver from its file basename. This lets `default.nix` derive both the `driver` enum and `settings` union from loaded drivers.

### Missing driver or role errors are explicit

The helper SHALL validate the selected driver and role before invoking role functions. Missing attributes SHALL fail evaluation with messages that include:

- service name
- selected driver
- requested role
- available drivers or roles
- expected file and attr shape

This is preferred over direct attr indexing because the default missing-attribute error lacks enough context for a developer to fix the service structure quickly.

### Matrix refactor partition

During the communications refactor, Matrix-specific interface, exports, and NixOS helpers move into `drivers/matrix.nix`:

- `interface`: Matrix driver settings type
- `roles.default.exports`: persistence, gateway, identity, observability, and well-known export fragments
- `roles.default.nixosModules`: bridge names, enabled bridge filtering, bridge admin rendering, bridge module builders, TURN secret/realm bindings, Synapse/LiveKit/TURN/firewall/systemd/vars fragments

Keep in `default.nix`: service manifest, driver discovery, shared options such as `identity`, shared interface assembly, role declaration, common fragments, and helper dispatch.

### Arrtrix/Servarr coupling remains a known follow-up

The current Matrix implementation still needs Arrtrix configuration that depends on Servarr-generated data. The refactor may move that code into `drivers/matrix.nix`, but it MUST NOT make the coupling more implicit. A later change should make this explicit through service exports or instance settings.

## Risks / Trade-offs

- Driver fragments may still grow large -> split private helpers inside the driver folder only after the driver boundary is established.
- Helper availability differs between path-registered services and locally imported services -> wire communications through `clan.specialArgs.ardaLib` now and document later alignment before applying this template to locally injected services.
- Auto-discovery can hide accidental files in `drivers` -> discovery should only load regular `.nix` files and driver files must expose the expected `interface` and `roles` shape.
- `types.oneOf` can accept structurally overlapping settings across future drivers -> keep driver schemas distinct where possible and revisit a callback submodule type if this becomes a real issue.
- Export composition changes from a single attrset to `mkMerge` fragments -> validate that `mkExports` accepts the merged export value and preserves the existing exports.
- Moving code without behavior changes can still affect evaluation order -> validate with targeted Nix evals and at least the affected machine toplevel.

## Migration Plan

1. Add shared Clan service helpers for driver discovery and selecting driver role fragments.
2. Expose the helpers through `clan/flake-module.nix` as `ardaLib.clanServices` and verify communications can resolve them.
3. Refactor communications to discover/import `drivers/matrix.nix`.
4. Move Matrix-specific interface, export fragments, and NixOS module fragments into `drivers/matrix.nix`.
5. Keep communications common service wiring and any common fragments in `default.nix`.
6. Validate Matrix appservice registrations and the affected machine toplevel evaluation for the machine that hosts the communications instance.
7. Use the resulting communications shape as the template for later service-specific driver refactors.

Rollback is straightforward: move the Matrix interface, exports, and module fragments back into `default.nix` and stop using the helper for communications.

## Open Questions

- What is the explicit composition shape for Arrtrix consuming Servarr material?
- Should locally injected services be converted to path-registered services or should their service-specific `flake-module.nix` files import the shared helper library directly?
