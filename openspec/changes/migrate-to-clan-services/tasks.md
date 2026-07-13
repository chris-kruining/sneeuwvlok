## 1. Normalize Existing Clan Service Layout

- [x] 1.1 Rename `clanServices/peristence` to `clanServices/persistence` and update all imports, paths, and flake-module references.
- [x] 1.2 Review existing `network`, `persistence`, `identity`, and `servarr` Clan services and document their current inputs, exports, drivers, and hardcoded repository-specific values.
- [x] 1.3 Ensure each existing Clan service exposes a consistent manifest name and registration name that matches the target service taxonomy.

## 2. Define Shared Capability Interfaces

- [x] 2.1 Refine the `persistence` export interface so database endpoints, selected driver, and requested databases can be passed explicitly between service instances.
- [x] 2.2 Refine the `gateway` export interface and `network.gateway` role so workload services can describe routes, endpoints, and reusable gateway functions without hardcoding gateway implementation details.
- [x] 2.3 Define the identity application declaration shape for workload OIDC needs while keeping Zitadel-specific reconciliation inside the identity service.
- [x] 2.4 Define initial `observability` and `backup` service interfaces without implementing unrelated runtime/container abstractions.

## 3. Complete Foundational Services

- [x] 3.1 Complete `persistence` with `driver = "postgresql"` and typed PostgreSQL settings.
- [x] 3.2 Complete `network` with machine-local port allocation in the default role and `driver = "caddy"` ingress in the gateway role.
- [x] 3.3 Complete `identity` with `driver = "zitadel"` only, including provider runtime, reconciliation, generated vars, and explicit application input handling.
- [x] 3.4 Add an initial `observability` Clan service skeleton with a driver-specific settings shape suitable for the current Grafana/Prometheus/Loki/Tempo stack.
- [x] 3.5 Add an initial `backup` Clan service skeleton with a driver-specific settings shape suitable for Borg.

## 4. Migrate Workload Services

- [x] 4.1 Create `version-control` as a generic Clan service with `driver = "forgejo"` and migrate the existing Forgejo service behavior into that driver.
- [x] 4.2 Create `communications` as a generic Clan service with `driver = "matrix"` and migrate the existing Matrix/Synapse communication behavior into that driver.
- [x] 4.3 Create `media` as a generic Clan service with `driver = "jellyfin"` and migrate the existing Jellyfin service behavior into that driver.
- [x] 4.4 Keep `servarr` as a concrete suite Clan service and align its inputs/exports with the shared persistence, gateway, and identity interfaces.

## 5. Update Composition

- [x] 5.1 Update `clan/instances.nix` so service instances pass concrete endpoints, provider material, and selected consumer settings explicitly.
- [x] 5.2 Move personal domains, machine placement, users, OIDC application choices, and secret prompts out of reusable service implementations and into instance settings or explicit inputs.
- [x] 5.3 Ensure provider services use typed export aggregation or explicit consumer settings rather than hidden service-to-service module dependencies.

## 6. Retire Dropped and Migrated Legacy Surfaces

- [x] 6.1 Remove Mydia, Nextcloud, and Minecraft from the active migration path and stop configuring them through service instances.
- [x] 6.2 Stop using legacy `sneeuwvlok.services.*` entry points for each service after its Clan replacement is validated.
- [x] 6.3 Keep boot, desktop, hardware, editor, shell, and baseline system modules outside this change except where required to preserve existing machine behavior.

## 7. Validate Migration

- [x] 7.1 Evaluate the Clan inventory after each migrated service is wired to confirm the service interface accepts only valid driver-specific settings.
- [x] 7.2 Build or evaluate affected machines after each service migration to confirm generated NixOS configuration remains valid.
- [x] 7.3 Review migrated Clan services for repository-specific assumptions before considering them ready for future community-service extraction.
