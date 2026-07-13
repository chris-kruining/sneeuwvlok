## 1. Endpoint Type Foundation

- [x] 1.1 Move endpoint `__toString` behavior into the shared `clan/types/endpoint.nix` type.
- [x] 1.2 Remove gateway-specific endpoint stringification once the shared endpoint type owns it.
- [x] 1.3 Normalize endpoint-shaped options and exports to use the shared endpoint type instead of ad hoc host/port/string options.
- [x] 1.4 Update endpoint string consumers to use `toString endpoint` where appropriate.

## 2. Endpoint Management Service

- [x] 2.1 Add a new endpoint management Clan service and register it through the existing `clanServices` flake-module discovery pattern.
- [x] 2.2 Define the service interface for generated endpoint settings, including an internal port range with sensible defaults.
- [x] 2.3 Implement per-machine claim aggregation that reads raw `ports.claims` exports only.
- [x] 2.4 Implement deterministic assignment by sorting claim keys and assigning unique ports from the configured range.
- [x] 2.5 Export per-machine assignments through `ports.assigned`.
- [x] 2.6 Fail with a clear range-exhaustion error when a machine has more claims than available ports.

## 3. Shared Generated Endpoint Helpers

- [x] 3.1 Add a small helper or convention for constructing namespaced claim keys.
- [x] 3.2 Add an endpoint helper that can declare one or more generated internal endpoints and returns endpoint-shaped values plus combined `ports.claims`.
- [x] 3.3 Add a helper object/function that wraps Clan export lookup and reads a generated endpoint's assigned port from `ports.assigned` for an explicit machine.
- [x] 3.4 Ensure missing assignments produce clear evaluation errors.

## 4. Validation

- [x] 4.1 Assert that assigned ports stay within the configured endpoint management range.
- [x] 4.2 Assert that endpoint management cannot assign duplicate ports on the same machine.
- [x] 4.3 Verify range exhaustion fails with the expected clear error.
- [x] 4.4 Add a minimal fixture or test service that declares multiple claims and verifies unique `ports.assigned` values.

## 5. Initial Consumer

- [x] 5.1 Convert one low-risk internal listener, such as `version-control` Forgejo, to declare an endpoint claim and read its endpoint from the shared helper.
- [x] 5.2 Verify the converted service uses the generated endpoint consistently for its NixOS module, gateway export, and observability target.
- [x] 5.3 Leave remaining hardcoded service ports unchanged for follow-up migrations.
