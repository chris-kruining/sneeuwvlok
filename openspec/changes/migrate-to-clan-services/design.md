## Context

The repository currently has two configuration surfaces:

- legacy NixOS modules under `modules/nixos`, exposed through `sneeuwvlok.*` options and imported into machines with `import-tree`;
- in-progress Clan services under `clanServices`, wired through `clan.inventory.instances`.

The Clan service work already shows the desired direction: foundational services such as `gateway`, `persistence`, and `identity` use generic service names and concrete implementation choices through a `driver` setting. Services can export capabilities, and the consumer/composition layer can pass selected service outputs into other service instances.

The main architectural constraint is that Clan services should remain black boxes. A service may expose and consume explicit interfaces, but it must not secretly discover other services or create hidden dependencies. The owner of `clan.inventory.instances` owns composition.

## Goals / Non-Goals

**Goals:**

- Define a stable service taxonomy for the first Clan migration pass.
- Preserve explicit consumer-owned composition between service instances.
- Use generic service names when the public capability is broader than the current implementation.
- Use typed driver-specific settings instead of generic escape hatches.
- Limit identity to a Zitadel implementation for this change.
- Define which legacy services are migrated, renamed, deferred, or dropped.
- Keep the design suitable for eventual extraction into a standalone community Clan services repository.

**Non-Goals:**

- Do not migrate boot, desktop, hardware, editor, shell, or baseline system modules in this change.
- Do not implement Himmelblau identity integration in this change.
- Do not introduce a generic runtime/container-runtime service.
- Do not migrate Mydia, Nextcloud, or Minecraft.
- Do not require all existing in-progress Clan services to be complete before this change can proceed incrementally.

## Decisions

### Use foundational and workload service categories

The initial Clan service catalog will distinguish:

| Category | Services |
| --- | --- |
| Foundational | `gateway`, `persistence`, `identity`, `observability`, `backup` |
| Generic workloads | `version-control`, `communications`, `media` |
| Concrete/suite workloads | `servarr` |
| Dropped legacy services | Mydia, Nextcloud, Minecraft |
| Deferred non-service concerns | boot, desktop, hardware, editor, shell, baseline system modules |

This avoids treating every Nix module as a Clan service while still allowing non-daemon services later if a cleaner tag-based policy model emerges.

Alternative considered: migrate all legacy modules into Clan services immediately. This was rejected because machine/profile concerns have not yet proven their long-term Clan shape and would distract from the service migration.

### Keep composition explicit in `clan.inventory.instances`

Service instances may export capability data, and other service instances may accept those values as settings. The composition layer decides which exports are passed where.

For example, a `persistence` instance can expose a PostgreSQL endpoint, and an `identity` instance can accept that endpoint as its `database` setting. The identity service must not implicitly locate or require a persistence instance on its own.

Alternative considered: have foundational services automatically collect all matching exports across the Clan. This was rejected for service-to-service dependencies where the consumer must own composition. Aggregation is acceptable only when the aggregator instance is explicitly configured to consume a scope or set of exported inputs.

### Use generic names with driver-specific interfaces

Generic services represent user-facing capabilities:

- `version-control` uses `driver = "forgejo"` initially.
- `communications` uses `driver = "matrix"` initially.
- `media` uses `driver = "jellyfin"` initially.
- `identity` uses `driver = "zitadel"` initially.
- `gateway`, `persistence`, `observability`, and `backup` use drivers for their concrete implementations.

Driver selection should determine the allowed settings shape. The design avoids untyped escape hatches such as `driverSettings.anything`; instead, the interface should expose only settings valid for the selected driver.

Alternative considered: keep concrete names such as `forgejo` and `jellyfin` for all services. This was rejected for capabilities likely to be useful to Clan community services with alternate implementations, such as Plex for `media`.

### Keep identity provider concerns separate from application identity needs

The `identity` service owns provider runtime and reconciliation concerns for Zitadel: organizations, users, projects, actions, OIDC clients, and generated client material.

Workload services should express identity needs as explicit input or exported capability data, but they should not own provider internals. The composition layer decides which application identity declarations are passed to the identity instance.

Alternative considered: keep all OIDC applications centrally declared inside the identity instance. This was rejected because it makes workload migrations less self-contained and forces the identity configuration to know too much about unrelated applications.

### Defer non-service module migration

Boot, desktop, hardware, editor, shell, and system baseline modules remain out of this change. Some may later benefit from Clan service placement through tags, such as applying boot animation to interactive machines, but that design should wait until core service migration patterns are proven.

Alternative considered: design tag-targeted policy services now. This was deferred to avoid overfitting before the foundational/workload service model stabilizes.

## Risks / Trade-offs

- Explicit composition may be more verbose than implicit discovery -> keep interfaces small and reusable so `clan/instances.nix` remains readable.
- Generic names can become too abstract -> only use generic names where a credible alternate driver exists or is expected.
- Driver-specific typed interfaces can be harder to model in Nix -> start with the current driver only and make the schema precise before adding alternates.
- Keeping non-service modules deferred may leave duplicate configuration surfaces temporarily -> migrate services incrementally and remove legacy service entry points only after replacements are wired.
- Eventual extraction to community services may expose repo-specific assumptions -> keep service code generic and push personal domain, machine, user, and secret choices into instance settings.

## Migration Plan

1. Normalize the existing Clan service layout, including fixing the `peristence` typo to `persistence`.
2. Define or refine shared interfaces for gateway, persistence, identity, observability, and backup capabilities.
3. Complete foundational services with explicit inputs and driver-specific typed settings.
4. Migrate workload services in priority order: `version-control` from Forgejo, `communications` from Matrix, `media` from Jellyfin, and retain `servarr` as a concrete suite service.
5. Drop Mydia, Nextcloud, and Minecraft legacy modules from the migration path.
6. Update `clan/instances.nix` so service instances are explicitly composed through settings and exported capability values.
7. Remove or stop using migrated legacy `sneeuwvlok.services.*` entry points once their Clan service replacement is validated.

Rollback is service-by-service: keep legacy service modules available until the corresponding Clan service instance produces equivalent configuration, then remove the old module usage only after parity is confirmed.

## Open Questions

- Should `observability` represent a single stack driver or split into smaller composable drivers for metrics, logs, traces, and dashboards?
- Should `backup` collect backup targets through an explicit input list, a scoped export aggregation, or direct per-service settings?
- What is the exact identity application declaration shape that balances workload ownership with explicit composition?
- Which migrated service should be completed first as the reference implementation for community-service extraction quality?
