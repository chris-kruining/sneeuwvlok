## Context

The repository is migrating from legacy NixOS modules under `modules/nixos` to Clan services under `clanServices`, wired through `clan.inventory.instances`.

The current implementation is the source of truth for this change. It has moved from a separate top-level `gateway` foundational service to a broader `network` service:

- `network.default` owns machine-local endpoint port allocation from `ports.claims`.
- `network.gateway` owns public ingress rendering with Caddy.
- `gateway` remains a shared export interface used by workloads to describe public services, routes, and reusable functions.

The main architectural constraint is still service black-boxing: reusable services expose typed interfaces and exports, while repository-specific choices live in `clan/instances.nix` or explicit settings. The current implementation also accepts provider-style aggregation for declarative needs such as database claims, port claims, and identity applications.

## Goals / Non-Goals

**Goals:**

- Document the current service taxonomy and the `network`/`gateway` split.
- Preserve typed capability exports across services.
- Use explicit settings for concrete runtime dependencies such as database endpoints and identity provider material.
- Allow bounded provider aggregation for declarative needs exported by workloads.
- Use generic service names when the public capability is broader than the current implementation.
- Use typed driver-specific settings instead of generic escape hatches.
- Limit identity to a Zitadel implementation for this change.
- Define which legacy services are migrated, renamed, deferred, or dropped.
- Keep the design suitable for eventual extraction into a standalone community Clan services repository.

**Non-Goals:**

- Do not migrate boot, desktop, hardware, editor, shell, or baseline system modules in this change.
- Do not implement Himmelblau identity integration in the Clan identity service in this change.
- Do not introduce a generic runtime/container-runtime service.
- Do not migrate Mydia, Nextcloud, or Minecraft.
- Do not require every legacy service module to be physically removed before the Clan replacement is the leading configuration surface.

## Decisions

### Use foundational and workload service categories

The current Clan service catalog distinguishes:

| Category | Services |
| --- | --- |
| Foundational | `network`, `persistence`, `identity`, `observability`, `backup` |
| Shared export interfaces | `gateway`, `identity`, `observability`, `persistence`, `backup`, `ports` |
| Generic workloads | `version-control`, `communications`, `media` |
| Concrete/suite workloads | `servarr` |
| Dropped legacy services | Mydia, Nextcloud, Minecraft |
| Deferred non-service concerns | boot, desktop, hardware, editor, shell, baseline system modules |

This avoids treating every Nix module as a Clan service while still allowing foundational services to provide common infrastructure capabilities.

Alternative considered: keep `gateway` as its own foundational service. The implementation moved beyond that: endpoint allocation and ingress are related network concerns but have different dependency boundaries, so `network.default` and `network.gateway` are separate roles.

### Split endpoint allocation from public ingress

`network.default` allocates machine-local ports from `ports.claims` for the same machine. It is deliberately blind to gateway routes and services.

`network.gateway` renders public ingress from configured `services`, `routes`, `functions`, and `hosts`. It does not feed endpoint allocation.

This creates the current flow:

```
workload service
  exports ports.claims
       gateway.services/routes
       identity.applications
       persistence.databases
          │
          ├── network.default -> ports.assigned
          ├── network.gateway -> Caddy virtual hosts, when configured
          ├── persistence     -> PostgreSQL databases/users
          └── identity        -> selected Zitadel applications
```

Workloads that need generated local endpoints use `ardaLib.endpoints.forService`, which reads assigned ports from the `network.default` export and returns endpoint values plus claims.

### Use typed exports plus explicit runtime settings

Runtime dependencies are passed as concrete settings where services need them. For example, `clan/instances.nix` resolves the `persistence` PostgreSQL endpoint and passes it as `database` to `identity` and `servarr`. It also resolves `identity.provider` and passes that provider material to workloads that need OIDC.

Declarative needs are exported as data and may be aggregated by provider services:

- `ports.claims` are aggregated by `network.default` per machine.
- `persistence.databases` are aggregated by `persistence` to provision databases and users.
- `identity.applications` are aggregated by `identity`, then selected through provider-project `consumers`.
- `gateway.services`, `gateway.routes`, and `gateway.functions` are exposed for gateway composition, but ingress rendering happens only from `network.gateway` settings.

This is less strictly hand-wired than the original design text, but it matches the current implementation and keeps cross-service coupling data-shaped rather than module-shaped.

### Use generic names with driver-specific interfaces

Generic services represent user-facing capabilities:

- `network.gateway` uses `driver = "caddy"` initially.
- `persistence` uses `driver = "postgresql"` initially.
- `identity` uses `driver = "zitadel"` initially.
- `observability` uses `driver = "grafana"` initially.
- `backup` uses `driver = "borg"` initially.
- `version-control` uses `driver = "forgejo"` initially.
- `communications` uses `driver = "matrix"` initially.
- `media` uses `driver = "jellyfin"` initially.

Driver selection determines the accepted settings shape. The design avoids untyped escape hatches such as `driverSettings.anything`; each current service exposes typed settings for its active driver.

Alternative considered: keep concrete names such as `forgejo` and `jellyfin` for all services. This was rejected for capabilities likely to be useful to Clan community services with alternate implementations, such as Plex for `media`.

### Keep identity provider concerns separate from application identity needs

The `identity` service owns Zitadel runtime and reconciliation concerns: organizations, users, projects, project roles, assignments, actions, triggers, OIDC clients, generated client material, and provider runtime settings.

Workload services may export `identity.applications` and may receive `identity.provider` material through settings. The provider instance controls placement by declaring project `consumers`, which select exported applications by name and merge them into the provider-side project configuration.

Application declarations are intentionally workload-level data. Zitadel organization, project placement, users, roles, actions, triggers, and reconciliation remain identity-provider settings.

The current implementation has two related shapes:

- shared workload application exports under `clan/interfaces/identity.nix`;
- provider-side application settings under `clanServices/identity/interface.nix`, including `origin`, `callbackPath`, explicit redirect URIs, grant/response types, and export maps.

Those shapes are allowed to differ because one is a workload declaration interface and the other is the provider reconciliation interface.

### Keep observability and backup as foundational skeletons

`observability` and `backup` exist as foundational services with typed driver settings and shared export interfaces.

`observability` currently models a Grafana-family stack: Grafana, Prometheus, Loki, Tempo, and Alloy. It can export observability inputs and optional gateway/identity/persistence declarations, but the full legacy Grafana dashboard, datasource, secret, and OIDC parity remains incremental.

`backup` currently models Borg repositories and targets. Workloads can describe backup targets through the shared backup interface, while concrete Borg repository configuration stays in the backup service settings.

### Defer non-service module migration

Boot, desktop, hardware, editor, shell, and system baseline modules remain out of this change. Some may later benefit from Clan service placement through tags, but that design should wait until core service migration patterns are proven.

Mydia, Nextcloud, and Minecraft are excluded from Clan service migration. Their modules or inputs may still exist in the repository while they are not configured as migrated Clan service instances.

## Risks / Trade-offs

- Provider aggregation can hide wiring if scopes are too broad -> keep exported interfaces typed and keep selection rules visible in provider services.
- `network` is broader than the original `gateway` name -> keep role boundaries explicit: allocation in `default`, ingress in `gateway`.
- Gateway exports can be produced without being rendered -> `network.gateway` settings remain the place where public ingress is actually enabled.
- Identity application shapes can diverge -> keep workload declarations and provider reconciliation settings intentionally separate.
- Driver-specific typed interfaces can be harder to model in Nix -> start with the current driver only and make the schema precise before adding alternates.
- Keeping non-service modules deferred may leave duplicate configuration surfaces temporarily -> the Clan instances are the leading surface, while legacy modules can remain available until removal is safe.
- Eventual extraction to community services may expose repo-specific assumptions -> keep service code generic and push personal domain, machine, user, and secret choices into instance settings.

## Migration Plan

1. Normalize the existing Clan service layout, including fixing the `peristence` typo to `persistence`.
2. Define or refine shared interfaces for `ports`, `gateway`, `persistence`, `identity`, `observability`, and `backup` capabilities.
3. Complete foundational services with typed driver-specific settings:
   - `network.default` for machine-local port allocation.
   - `network.gateway` for Caddy ingress.
   - `persistence` for PostgreSQL endpoints and database/user provisioning.
   - `identity` for Zitadel runtime, reconciliation, provider export, and selected application inputs.
   - `observability` and `backup` as typed skeletons.
4. Migrate workload services in priority order: `version-control` from Forgejo, `communications` from Matrix, `media` from Jellyfin, and retain `servarr` as a concrete suite service.
5. Drop Mydia, Nextcloud, and Minecraft from the Clan migration path.
6. Update `clan/instances.nix` so concrete endpoints, provider material, consumer lists, machine placement, domains, users, OIDC choices, and secret prompts are instance-owned.
7. Stop using migrated legacy `sneeuwvlok.services.*` entry points as the leading configuration surface once Clan service instances exist.

Rollback is service-by-service: keep legacy service modules available until the corresponding Clan service instance produces equivalent configuration, then remove the old module usage only after parity is confirmed.

## Current Clan Service Review

| Service | Registered module | Manifest name | Current inputs | Current exports | Driver/settings shape | Repository-specific values in instances/settings |
| --- | --- | --- | --- | --- | --- | --- |
| `network` | `clan.modules.network` | `network` | `default` role consumes same-machine `ports.claims`; `gateway` role consumes configured `services`, `routes`, `functions`, and `hosts` | `default` exports `ports.assigned`; `gateway` renders Caddy config but does not export allocation data | `default` has typed port range settings; `gateway` has `driver = "caddy"` and typed ingress settings | Machine tags and gateway service wiring live in `clan/instances.nix`; Caddy package/plugin choice remains implementation-owned |
| `persistence` | `clan.modules.persistence` | `persistence` | Aggregates exported `persistence.databases` and accepts PostgreSQL settings | Exports selected `driver = "postgresql"` and endpoint under `persistence.endpoints.postgresql` | `driver = "postgresql"` with typed `postgresql.host` and `postgresql.port` settings | Certificate CN uses machine FQDN; database consumers are discovered from typed exports |
| `identity` | `clan.modules.identity` | `identity` | Accepts explicit `database` endpoint; aggregates exported `identity.applications`; project `consumers` select applications | Exports `gateway.services.identity`, `gateway.functions.auth`, `identity.provider`, and `persistence.databases = ["zitadel"]` | `driver = "zitadel"` only; typed database, port, origin/domain, SMTP, organizations, users, projects, roles, assignments, applications, actions, triggers | Domain, SMTP details, users, org/project/application choices, role claims, and trigger policy live in instance settings |
| `observability` | `clan.modules.observability` | `observability` | Accepts observability inputs and optional `identity.provider` material | Can export Grafana gateway service, Grafana identity application, Grafana database claim, and observability metrics/logs/traces | `driver = "grafana"` with typed Grafana/Prometheus/Loki/Tempo/Alloy enablement and ports | Grafana host and provider material live in instance settings |
| `backup` | `clan.modules.backup` | `backup` | Accepts backup targets and Borg repository settings | Backup interface is available for target declarations | `driver = "borg"` with typed repositories, target hooks, compression, encryption, environment, and SSH config | Repositories and targets live in instance settings |
| `version-control` | `clan.modules."version-control"` | `version-control` | Accepts `identity.provider`; uses `network.default` port assignments through endpoint helper | Exports port claims, Forgejo gateway service, Forgejo identity app, Forgejo database claim, and metrics target | `driver = "forgejo"` with typed Forgejo, mailer, and runner settings | Domain, branding, CORS, runner labels, and provider material live in instance settings |
| `communications` | `clan.modules.communications` | `communications` | Accepts `identity.provider`; uses typed Matrix settings | Exports Matrix gateway service/routes, Matrix identity app, Synapse database claim, metrics, and traces | `driver = "matrix"` with typed Matrix, bridges, LiveKit, and TURN settings | Domains, bridge set, LiveKit/TURN enablement, and provider material live in instance settings |
| `media` | `clan.modules.media` | `media` | Accepts `identity.provider`; uses `network.default` port assignments through endpoint helper | Exports port claims, Jellyfin gateway service, Jellyfin identity app, and metrics target | `driver = "jellyfin"` with typed media path and identity settings | Media path and provider material live in instance settings |
| `servarr` | `clan.modules.servarr` | `servarr` | Accepts explicit `database` endpoint and suite service settings | Exports per-service `persistence.databases` and `gateway.services` | Concrete suite settings: enabled services, optional host, root folders, media path | Media path, suite service set, and helper assumptions for sabnzbd/qbittorrent/flaresolverr live in service settings/implementation |

## Open Questions

- Should `network.gateway` consume workload `gateway` exports directly through a selected scope, or should `clan/instances.nix` continue to materialize its `services` settings explicitly?
- Should `persistence` narrow database aggregation to explicit export scopes rather than all visible `persistence.databases` exports?
- Should identity application selection include export scopes in addition to project `consumers` names?
- Should more workloads adopt `ardaLib.endpoints.forService` so all local ports come from `network.default`?
- How much legacy observability and backup parity is required before the legacy modules can be removed?
