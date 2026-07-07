## Why

The repository is partway through migrating from legacy `sneeuwvlok` NixOS modules to Clan services, but the target service taxonomy, composition model, and migration scope are not yet captured. Defining the migration contract now keeps the branch focused and avoids baking unfinished service boundaries into the implementation.

## What Changes

- Introduce a Clan-service migration model that separates foundational services, generic workload services, concrete suite services, dropped legacy services, and deferred non-service concerns.
- Establish explicit consumer-owned composition: service instances may expose capabilities and accept other service instances as inputs, but services must not create hidden dependencies or implicit cross-service side effects.
- Use generic service names with driver-specific typed settings where the public capability is broader than the current implementation.
- Limit the initial identity implementation to the Zitadel driver, while leaving future identity drivers such as Himmelblau out of scope.
- Define migration scope for current legacy services, including dropping Mydia, Nextcloud, and Minecraft instead of migrating them.
- Defer boot, desktop, hardware, editor, shell, and baseline system module migration until the core service migration has stabilized.
- **BREAKING**: Legacy `sneeuwvlok.services.*` module entry points for migrated or dropped services will no longer be the primary configuration surface once their Clan service replacement is complete.

## Capabilities

### New Capabilities

- `clan-service-migration`: Defines the target Clan service taxonomy, explicit composition model, driver-specific service settings, and migration scope for legacy service modules.

### Modified Capabilities

- None.

## Impact

- Affected areas include `clan/instances.nix`, `clan/interfaces/*.nix`, `clanServices/*`, and legacy service modules under `modules/nixos/services`.
- The migration will introduce or reshape Clan services for `gateway`, `persistence`, `identity`, `observability`, `backup`, `version-control`, `communications`, `media`, and `servarr`.
- Legacy Mydia, Nextcloud, and Minecraft service modules are intentionally excluded from migration.
- Non-service machine/profile concerns remain available as Nix modules for now and are not redesigned by this change.
