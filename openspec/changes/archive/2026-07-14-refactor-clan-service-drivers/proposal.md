## Why

Clan service implementations currently mix service wiring, driver selection, and driver-specific NixOS configuration in `default.nix`, which makes modules hard to read and encourages abstraction leaks between services. The communications service exposes this most clearly after the Matrix migration, and the same pattern should become reusable for identity, media, version-control, observability, and other driver-backed services.

## What Changes

- Introduce a repository-wide Clan service driver layout convention using `clanServices/<service>/drivers/<driver>.nix`.
- Require driver files to expose driver-specific `interface` plus role-named behavior under `roles`, with `roles.default` as the standard role entry point.
- Add shared library helpers that discover/select the configured driver and role, return export and NixOS fragments suitable for appending into `mkMerge` lists, and fail with clear guidance when a driver or role is missing.
- Refactor the communications service so `default.nix` contains service manifest, driver discovery, shared interface assembly, role wiring, common fragments, and driver dispatch while `drivers/matrix.nix` contains Matrix-specific interface, exports, and NixOS module fragments.
- Use the communications refactor as the template for later driver-backed Clan service cleanups.

## Capabilities

### New Capabilities
- `clan-service-drivers`: Driver-backed Clan services use explicit driver files, driver-owned interface definitions, role-named export/NixOS fragments, and shared driver dispatch helper behavior.

### Modified Capabilities
- `clan-service-migration`: Driver-specific service interfaces, exports, and NixOS implementations are structured behind service-owned driver folders rather than living directly in each service `default.nix`.

## Impact

- Affected code: `clanServices/communications`, shared `lib`, `clan/flake-module.nix` special-args wiring, and later driver-backed services that adopt the template.
- Affected interfaces: no intended change to external Clan instance configuration beyond preserving the current `driver` plus driver-specific `settings` shape.
- Affected behavior: no intended runtime behavior change for Matrix; this is an implementation-structure refactor with clearer failure modes for missing driver or role modules.
