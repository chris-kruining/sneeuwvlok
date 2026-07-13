## Context

The repository currently has two related Clan services:

- `endpoint-management` is evaluation-only. It aggregates raw `ports.claims` for each machine and exports deterministic machine-local `ports.assigned` values.
- `gateway` renders public ingress with `driver = "caddy"` from explicit `services`, `routes`, and `functions` settings.

The current endpoint-management design already establishes the critical dependency boundary:

```text
ports.claims -> ports.assigned -> service endpoint exports -> gateway routes
```

The unsafe shape remains:

```text
gateway/service endpoint exports -> ports.assigned -> gateway/service endpoint exports
```

This change rebrands the broader concern as `network` while keeping allocation and ingress as separate roles with separate responsibilities.

## Goals / Non-Goals

**Goals:**

- Replace the standalone `endpoint-management` service with a `network.default` role that owns machine-local generated endpoint allocation.
- Move current gateway behavior into a `network.gateway` role that owns public ingress rendering.
- Keep endpoint allocation outside gateway drivers such as Caddy.
- Preserve the current `ports.claims` and `ports.assigned` export contract.
- Preserve explicit composition for gateway routes and services.
- Keep the two roles independently understandable, testable, and reviewable despite sharing a service namespace.

**Non-Goals:**

- Do not make generated ports stable across service additions or removals.
- Do not make generated ports globally unique across the clan.
- Do not replace explicit public or protocol-required ports.
- Do not introduce automatic gateway route aggregation in this change.
- Do not let gateway route/service exports feed endpoint allocation.

## Decisions

### Use `network` as the service namespace

`network` becomes the broader Clan service namespace for machine-local endpoint allocation and ingress routing. This makes `gateway` a role of the network service rather than the whole service identity.

Alternative considered: keep `endpoint-management` and `gateway` as separate services. That keeps a stronger physical boundary, but preserves a taxonomy where endpoint allocation appears unrelated to gateway/public networking. The role split gives a clearer catalog while retaining the important data-flow boundary.

### Keep endpoint allocation in `network.default`

`network.default` owns generated endpoint allocation. It should be applied broadly, using `tags = ["all"]`, so machines without ingress still receive generated internal endpoint assignments.

The role reads only raw `ports.claims` for the current machine and exports `ports.assigned`. It does not read `gateway.services`, `gateway.routes`, or any endpoint exports that may already depend on assigned ports.

Alternative considered: place allocation under the gateway role. That would incorrectly tie internal listener assignment to machines that run public ingress and would blur allocation into the gateway driver scope.

### Keep ingress in `network.gateway`

`network.gateway` owns public ingress rendering. The current `gateway` service behavior moves here, including `driver = "caddy"`, hosts, routes, reusable functions, and reverse proxy generation.

`network.gateway.perInstance` should consume explicit settings only. It should not bind or use `exports` or `clanLib` directly as part of this change. That keeps gateway route composition explicit in `clan/instances.nix` and avoids accidentally introducing a broad export aggregator.

Alternative considered: have the gateway role auto-collect `gateway.*` exports. That may be useful later, but it is a separate design decision because it changes the explicit composition model and increases cycle risk.

### Keep roles physically separated in code

Although both behaviors live under the `network` service namespace, allocation and ingress should be implemented in separate role files or modules. Shared top-level code should be limited to pure constants or imports that cannot make gateway failures affect endpoint allocation.

This is a guardrail against the main merge risk: the old service split made dependency violations easier to notice. Separate role files preserve much of that reviewability.

### Preserve the existing ports interface

The shared `ports` export interface remains the low-level contract:

```nix
ports.claims = { ... };
ports.assigned = { ... };
```

Generated endpoint helpers should continue to return endpoint-shaped values to service authors. The default helper lookup changes from the old `endpoint-management` service/instance to the new `network` service and default role.

### Rename in one cut-over

The rename affects hardcoded service and instance names. The implementation should update all references together, including service registration, inventory, helper defaults, tests, and documentation.

Leaving compatibility aliases is not required for this repository-local migration, but the helper should keep configurable service/instance/role parameters so future transitional use remains possible.

## Risks / Trade-offs

- Same-service roles can make accidental dependency cycles easier to introduce -> keep role implementations separate and document that `network.gateway` must not feed allocation.
- `network` is broader than the current behavior and may be confused with DNS, firewall, or VPN concerns -> keep the role names precise and document the service scope as endpoint allocation plus ingress.
- Manifest-level export declarations are not per-role -> keep the service manifest contract narrow and avoid implying that the gateway role consumes or produces `ports`.
- Rename blast radius is wider than a pure refactor -> grep-audit hardcoded `endpoint-management` strings and update tests in the same change.
- A gateway implementation error could affect allocation if shared eagerly evaluated code grows too large -> keep shared code minimal and validate allocation independently from gateway rendering.

## Migration Plan

1. Introduce the `network` service layout with separate default allocation and gateway role modules.
2. Move endpoint-management settings and assignment logic into `network.default`.
3. Move gateway interface and Caddy rendering into `network.gateway`.
4. Register the `network` module and update `clan/instances.nix` to replace the `endpoint-management` and `gateway` service instances with `network.roles.default` and `network.roles.gateway`.
5. Update `lib/endpoints.nix` defaults to read `ports.assigned` from `serviceName = "network"` and `roleName = "default"`.
6. Update checks and fixtures that hardcode `endpoint-management`.
7. Remove the old `endpoint-management` and `gateway` service registrations once the network roles are wired.

Rollback is straightforward before removing the old services: restore the original inventory instances and helper defaults. After removal, rollback requires restoring the old service directories or reverting the change.

## Open Questions

- Should the network instance name default to `"network"` everywhere, or should helper parameters keep a more generic allocator instance name?
- Should gateway documentation keep a searchable alias for users looking for the old `gateway` service?
