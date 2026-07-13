## 1. Network Service Structure

- [x] 1.1 Create a `network` Clan service layout with separate role modules/files for `default` endpoint allocation and `gateway` ingress.
- [x] 1.2 Move the endpoint allocation interface, range settings, README content, and assignment logic from `endpoint-management` into `network.default`.
- [x] 1.3 Move the gateway interface, README content, and Caddy rendering logic from `gateway` into `network.gateway`.
- [x] 1.4 Keep shared top-level network code minimal so gateway evaluation errors cannot affect endpoint allocation.

## 2. Inventory and Registration

- [x] 2.1 Register the new `network` Clan module and remove the old `endpoint-management` and `gateway` module registrations.
- [x] 2.2 Update `clan/instances.nix` so `network.roles.default` uses `tags = ["all"]`.
- [x] 2.3 Update `clan/instances.nix` so `network.roles.gateway` uses `tags = ["operational:role:gateway"]` and carries the existing gateway settings.
- [x] 2.4 Preserve the explicit gateway composition model; do not add automatic gateway export aggregation.

## 3. Endpoint Helper Migration

- [x] 3.1 Update `lib/endpoints.nix` defaults to read assignments from `serviceName = "network"` and `roleName = "default"`.
- [x] 3.2 Rename helper parameters that still say endpoint-management while keeping service, instance, and role lookup configurable.
- [x] 3.3 Ensure generated endpoint helper errors mention the network default allocation role when assignments are missing.
- [x] 3.4 Grep-audit and update all hardcoded `endpoint-management` service or instance references.

## 4. Boundary Guardrails

- [x] 4.1 Ensure `network.default` reads only raw `ports.claims` and endpoint allocation settings while computing `ports.assigned`.
- [x] 4.2 Ensure `network.gateway` consumes explicit settings and does not use `exports` or `clanLib` directly in this change.
- [x] 4.3 Add concise code comments or documentation near the role boundary explaining that gateway exports must not feed allocation.

## 5. Validation

- [x] 5.1 Update endpoint-management checks/fixtures to use the new `network` export key shape.
- [x] 5.2 Verify generated endpoint assignments remain deterministic and report range exhaustion clearly.
- [x] 5.3 Verify a generated endpoint can still feed a gateway route endpoint after the rename.
- [x] 5.4 Run the smallest existing Nix/OpenSpec checks that cover the helper migration, allocation role, and gateway role wiring.
