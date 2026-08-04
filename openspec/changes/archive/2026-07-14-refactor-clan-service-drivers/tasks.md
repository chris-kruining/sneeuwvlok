## 1. Shared Driver Helper

- [x] 1.1 Add a shared Clan service helper library function that discovers driver files from a service-owned `drivers` directory.
- [x] 1.2 Make driver discovery import and apply each regular `.nix` driver file with supplied pure arguments such as `lib`.
- [x] 1.3 Add a shared Clan service helper library function that selects a driver and role and returns export and NixOS module fragment lists for appending into `mkMerge`.
- [x] 1.4 Make the helper fail with explicit messages for missing driver attrs, including service name, selected driver, available drivers, and expected driver file shape.
- [x] 1.5 Make the helper fail with explicit messages for missing role attrs, including service name, selected driver, requested role, available roles, and expected role attr shape.
- [x] 1.6 Wire the helpers into `clan/flake-module.nix` under `clan.specialArgs.ardaLib.clanServices` for path-registered Clan services.
- [x] 1.7 Verify the communications service can resolve the `ardaLib.clanServices` helpers through Clan service evaluation.
- [x] 1.8 Document or note that locally injected `ardaLib` service patterns, such as media and version-control, need later alignment before adopting the helper.

## 2. Communications Driver Refactor

- [x] 2.1 Create `clanServices/communications/drivers/matrix.nix` exposing `interface` and `roles.default`.
- [x] 2.2 Move the Matrix-specific settings type from the communications interface into `drivers/matrix.nix.interface`, keeping driver top-level evaluation free of NixOS `config`, role settings, `pkgs`, and per-instance values.
- [x] 2.3 Move Matrix-specific export fragments for persistence, gateway, identity, observability, and well-known routes into `drivers/matrix.nix.roles.default.exports`.
- [x] 2.4 Move Matrix-specific NixOS helpers and module fragments into `drivers/matrix.nix.roles.default.nixosModules`, including bridge builders, enabled bridge filtering, TURN bindings, Synapse, LiveKit, TURN, firewall, systemd, vars, and Arrtrix runtime fragments.
- [x] 2.5 Update `clanServices/communications/default.nix` so it accepts `ardaLib`, discovers drivers, derives the driver enum and settings union from discovered drivers, preserves the `driver = "matrix"` default and current `driver` plus `settings` instance shape, assembles shared options inline, and composes common plus selected driver fragments with `mkMerge`.
- [x] 2.6 Remove the now-obsolete separate communications `interface.nix` if all interface wiring has moved into `default.nix`.
- [x] 2.7 Preserve existing Matrix exports for persistence, gateway, identity, and observability.
- [x] 2.8 Preserve existing Matrix runtime behavior for Synapse, LiveKit, TURN, bridge registrations, and Arrtrix environment generation.

## 3. Validation

- [x] 3.1 Evaluate the communications Matrix Synapse appservice registration list and confirm the existing bridges are still registered.
- [x] 3.2 Confirm the machine used for validation hosts the communications instance, then evaluate that machine NixOS toplevel.
- [x] 3.3 Run `git diff --check` to verify the refactor does not introduce whitespace errors.
- [x] 3.4 Verify a deliberately missing driver or role produces the helper's custom error message, without committing the negative test configuration.
- [x] 3.5 Verify `mkExports (mkMerge (...))` preserves the expected communications exports after moving Matrix exports into driver fragments.
- [x] 3.6 Review the resulting communications structure as the template for future identity, version-control, media, observability, backup, persistence, and network driver refactors.
