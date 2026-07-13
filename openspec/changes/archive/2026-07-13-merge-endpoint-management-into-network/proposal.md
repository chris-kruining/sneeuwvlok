## Why

Endpoint allocation and public ingress are both network-facing concerns, but they are currently split between `endpoint-management` and `gateway` services. Rebranding them under a single `network` service with separate roles clarifies the taxonomy while preserving the evaluation boundary that keeps internal port allocation safe.

## What Changes

- Replace the standalone `endpoint-management` service with a broader `network` service.
- Move generated internal endpoint allocation into `network.default`, intended for `tags = ["all"]`.
- Move the current gateway behavior into `network.gateway`, intended for `tags = ["operational:role:gateway"]`.
- Keep gateway/ingress implementation details, such as `driver = "caddy"`, scoped to the gateway role.
- Preserve the allocation dependency boundary: `network.default` reads only raw `ports.claims` and writes `ports.assigned`; it must not inspect gateway service or route exports.
- Update generated endpoint helpers and tests to read assignments from the `network` service instead of `endpoint-management`.
- **BREAKING**: Clan inventory instances and helper defaults that reference `endpoint-management` must be renamed to `network`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `endpoint-management`: Generated endpoint allocation remains the same behaviorally, but its owning Clan service changes from `endpoint-management` to the `network.default` role while preserving `ports.claims` and `ports.assigned` as the export contract.

## Impact

- Affects `clanServices/endpoint-management`, `clanServices/gateway`, their module registrations, and `clan/instances.nix`.
- Affects `lib/endpoints.nix` defaults and tests that hardcode the endpoint-management service/instance name.
- Keeps the shared endpoint type and `ports` export interface intact.
- No new runtime dependency is expected; endpoint allocation remains derived during Nix evaluation.
