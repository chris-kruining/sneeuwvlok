## Why

Endpoint-shaped values are not consistently modeled across services today, which leads to ad hoc host/port strings, duplicated URL formatting, and awkward gateway/observability binding. Internal port allocation is one part of this broader endpoint management problem: generated internal endpoints need machine-local unique ports, while public stability belongs to gateway/service exports.

## What Changes

- Normalize endpoint consumers to use the shared endpoint type, including shared endpoint stringification through `__toString`.
- Add endpoint helpers that let services declare one or more generated internal endpoints and receive endpoint-shaped values.
- Add machine-local port allocation as the mechanism for assigning unique ports to generated internal endpoints.
- Keep raw port assignment plumbing under `ports.assigned`, but expose ergonomic endpoint-shaped values to service authors.
- Add helper functions around export lookup so consumers can read generated endpoint assignments without hand-rolling `getExport` plumbing.
- Move consumers toward passing endpoint values between exports instead of owning hardcoded default internal ports or formatting endpoint strings manually.
- Keep public addressing and routing in gateway/service exports; generated internal ports are not a public API.

## Capabilities

### New Capabilities
- `endpoint-management`: Shared endpoint typing, endpoint stringification, endpoint-shaped generated listeners, and machine-local port allocation for internal endpoints.

### Modified Capabilities

None.

## Impact

- Adds a new Clan service for endpoint management and generated internal endpoint allocation.
- Introduces internal port claim and assignment export shapes under `ports.claims` and `ports.assigned`.
- Adds shared helper code for endpoint claim construction and generated endpoint lookup.
- Updates endpoint-shaped options and exports to use the shared endpoint type instead of ad hoc host/port strings.
- Affects Clan services that currently hardcode internal listener ports, such as version-control, identity, communications, observability, media, and servarr.
- No new external runtime dependency is expected; assignment is derived during Nix evaluation.
