## Context

Several Clan services configure internal endpoints indirectly today through loose host/port settings, explicit port defaults, string targets, and local URL formatting. Examples include fixed defaults for Forgejo, Zitadel, Matrix, Grafana components, Jellyfin, PostgreSQL, and generated offsets inside Servarr. These endpoints are internal wiring for NixOS services on a machine; public access is already better represented by gateway routes and exported endpoints.

Endpoint management needs to fit Clan service evaluation. Claims cannot mutate shared state during evaluation, so services must publish generated-endpoint claims as export data. A dedicated endpoint management service can aggregate those claims per machine, derive port assignments, and publish generated endpoint data back through exports.

## Goals / Non-Goals

**Goals:**

- Make the shared endpoint type the contract for endpoint-shaped values between services.
- Provide shared endpoint stringification so callers can use `toString endpoint` instead of formatting endpoint strings by hand.
- Provide generated internal endpoints for NixOS service listeners.
- Keep the claim API minimal: services claim named internal endpoints without declaring bind address or public routing metadata.
- Use machine-local port allocation to assign unique ports to generated internal endpoints.
- Keep raw assigned ports available through `ports.assigned` as implementation plumbing.
- Derive assignments during Nix evaluation without persistent state or generated lock files.
- Preserve gateway exports as the place where public domains and routes are managed.

**Non-Goals:**

- Stable generated ports across service additions/removals.
- Globally unique ports across the whole clan.
- Replacing explicit public/protocol ports such as 22, 80, 443, federation ports, or externally required protocol defaults.
- Automatically rewriting every existing service in the initial implementation.

## Decisions

### Use a Clan service for endpoint management

Endpoint management will include a Clan service so it can use the existing exports system. Other services export raw generated-endpoint claims; the service aggregates those claims and exports resolved port assignments under `ports.assigned`.

Alternative considered: inject a `ports.claim` function into `perInstance`. That does not match Nix evaluation because such a function cannot mutate shared state. Returning claim data through exports keeps evaluation pure.

### Claims are simple named endpoint needs

A claim represents "this NixOS service endpoint needs one generated internal endpoint". It does not include bind address or public routing metadata.

Example claim shape:

```nix
ports.claims."version-control/${instanceName}/forgejo" = { };
```

The key must be unique enough for the claiming module to read its assignment later. For services that spawn multiple NixOS services, such as Servarr, each spawned listener claims a separate generated endpoint key.

Alternative considered: include bind address in each claim. That was rejected for the initial design because endpoint management only needs to prevent port-number collisions per machine, while service modules already own their own socket semantics.

### Helpers return endpoint-shaped values

The endpoint helper should expose claimed listeners as endpoint-shaped values, not as raw port records. This lets generated endpoints bind directly into gateway, observability, and other endpoint-consuming exports.

Conceptual usage:

```nix
endpoints = ardaLib.endpoints.forService {
  inherit exports clanLib machine instanceName;
  serviceName = "version-control";
};

internal = endpoints.internal [ "forgejo" ];

exports = mkExports {
  ports.claims = internal.claims;
  gateway.services.forgejo.endpoint = internal.forgejo;
};
```

For services that need multiple NixOS listeners, the helper must support multiple endpoint claims in one call:

```nix
internal = endpoints.internal [
  "sonarr"
  "radarr"
  "lidarr"
  "prowlarr"
  "sabnzbd"
  "qbittorrent"
  "flaresolverr"
];
```

Each endpoint value should match the shared endpoint type shape, including `protocol`, `host`, and `port`, so callers can use `.port` where a service module needs only a port and pass the whole endpoint where an endpoint option is expected.

### Endpoint stringification belongs to the endpoint type

The shared endpoint type should provide `__toString`, so callers do not repeatedly format `"${host}:${port}"` or `"${protocol}://${host}:${port}"` by hand. Existing local endpoint stringification in gateway-specific interfaces should move to the shared endpoint type.

All options and exports that accept endpoint-shaped data should use the shared endpoint type. This avoids passing endpoint attrsets through stringly typed or ad hoc host/port options, and it avoids stripping `__toString` when endpoint values are passed between services.

Known endpoint consumers to normalize include gateway service endpoints, persistence/database endpoints, observability scrape targets that represent service endpoints, and service settings that currently carry internal listener host/port pairs.

### Port assignments are internal endpoint plumbing

The endpoint management service exports raw port assignments under `ports.assigned`, not under an allocator-specific namespace. This keeps the low-level read side focused on the underlying port capability while service authors normally interact with endpoint-shaped helper values.

Conceptual shape:

```nix
exports.ports.assigned.${machine.name}."version-control/default/forgejo" = 20000;
```

Helpers read the assignment for their current machine and claim key, then return endpoint-shaped values for NixOS modules and service exports.

Because cross-service exports are normally read through explicit composition, the implementation should provide a small helper object in the shared library rather than requiring each consumer to hand-roll `getExport` access. The helper should wrap the existing Clan export lookup shape and expose a narrower port-focused API.

Conceptual composition usage:

```nix
endpoints = ardaLib.endpoints.forService {
  inherit exports clanLib machine instanceName;
  serviceName = "version-control";
};

forgejo = (endpoints.internal [ "forgejo" ]).forgejo;
```

The exact function names can still evolve during implementation, but the helper should make two things explicit: which machine's assignment export is being read, and which claim key is being resolved.

### Port assignments are deterministic over the current machine claims

For each machine, endpoint management collects enabled generated-endpoint claims, sorts claim keys deterministically, and assigns ports from an internal range in order. Existing hardcoded service ports are considered legacy during migration and do not need to be reserved by the initial endpoint management service.

This means generated ports may change when claims are added or removed. That is acceptable because generated internal ports are not public API. Public stability belongs to gateway routes and service exports.

### Avoid export cycles

Endpoint management must read only raw `ports.claims`. It must not read gateway endpoint ports or any exports that already depend on `ports.assigned`.

Safe flow:

```text
ports.claims -> ports.assigned -> gateway/service endpoint exports
```

Unsafe flow:

```text
gateway/service endpoint exports -> ports.assigned -> gateway/service endpoint exports
```

## Risks / Trade-offs

- Generated endpoint ports can shift when the enabled claim set changes -> Keep generated endpoints internal-only and route public access through gateway exports.
- Services may accidentally depend on generated ports externally -> Document that `ports.assigned` values are implementation details and should not be user-facing API.
- Missing endpoint management service could produce confusing evaluation errors -> Provide clear assertions or helper errors when a service reads a missing assignment.
- The configured range can be too small for the enabled claim set -> Fail evaluation with a clear range-exhaustion error that includes the machine name, claim count, and range size.
- Export aggregation may introduce recursion if implemented too broadly -> Limit endpoint management inputs to `ports.claims` only.
- Claim key collisions between services could overwrite data -> Use namespaced claim keys and assert duplicate claim definitions where practical.
- Endpoint-shaped data is currently not consistently typed as endpoints -> Normalize endpoint consumers before relying on endpoint values flowing between services.

## Migration Plan

1. Move endpoint stringification into the shared endpoint type and normalize endpoint consumers to use that type.
2. Add the endpoint management service and shared helpers/types for generated endpoints, `ports.claims`, and `ports.assigned`.
3. Add a small initial consumer or test fixture to prove claim aggregation and assignment.
4. Migrate services incrementally from hardcoded internal defaults to claim-based assignment.
5. Keep explicit ports for public/protocol-required listeners.

Rollback is straightforward for migrated services: restore explicit endpoint/port settings and stop reading generated endpoint helpers.

## Open Questions

- Should the default internal allocation range be configurable globally, per machine, or both?
- What exact helper API should service authors use to build claim keys and read assignments?
