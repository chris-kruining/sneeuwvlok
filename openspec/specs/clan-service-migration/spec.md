# clan-service-migration Specification

## Purpose
TBD - Captures requirements for migrating repository services to Clan service boundaries.

## Requirements

### Requirement: Service taxonomy
The migration SHALL classify service work into foundational services, generic workload services, concrete suite services, dropped legacy services, and deferred non-service concerns.

#### Scenario: Foundational services are identified
- **WHEN** the migration catalog is reviewed
- **THEN** `network`, `persistence`, `identity`, `observability`, and `backup` are treated as foundational services
- **AND** public ingress is represented as the `network.gateway` role and shared `gateway` export interface rather than as a separate top-level `gateway` service

#### Scenario: Workload services are identified
- **WHEN** the migration catalog is reviewed
- **THEN** `version-control`, `communications`, and `media` are treated as generic workload services
- **AND** `servarr` is treated as a concrete suite service

#### Scenario: Dropped services are excluded
- **WHEN** migration tasks are planned
- **THEN** Mydia, Nextcloud, and Minecraft are excluded from Clan service migration

#### Scenario: Non-service concerns are deferred
- **WHEN** migration tasks are planned
- **THEN** boot, desktop, hardware, editor, shell, and baseline system modules are not migrated by this change

### Requirement: Explicit service composition
Clan service instances SHALL expose typed capability exports and consume other services through explicit settings, selected provider material, consumer lists, or bounded export aggregation matching the current implementation.

#### Scenario: Service consumes another service explicitly
- **WHEN** a service requires a capability provided by another service instance
- **THEN** the required runtime endpoint or provider material is passed through the consuming service instance settings
- **AND** exported capability declarations remain data that provider or aggregator services can select

#### Scenario: Service remains a black box
- **WHEN** a Clan service is implemented
- **THEN** it exposes documented inputs and outputs
- **AND** it does not rely on hidden dependencies or implicit side effects from unrelated services

#### Scenario: Network allocates machine-local ports
- **WHEN** services export `ports.claims`
- **THEN** `network.default` assigns ports from those claims for the same machine
- **AND** `network.gateway` does not feed port allocation

#### Scenario: Network renders ingress
- **WHEN** ingress is configured
- **THEN** `network.gateway` renders Caddy virtual hosts from configured `services`, `routes`, and `functions`
- **AND** workload `gateway` exports are only exposed for the composition layer or gateway settings to consume

#### Scenario: Provider services aggregate declarative needs
- **WHEN** workloads export declarative capability needs such as `persistence.databases` or `identity.applications`
- **THEN** provider services may aggregate those exports to provision databases or identity applications
- **AND** identity project `consumers` select which exported applications are materialized for a provider project

### Requirement: Driver-specific settings
Generic Clan services SHALL expose a `driver` option when the service capability can have multiple concrete implementations, and the accepted settings SHALL be shaped by the selected driver.

#### Scenario: Initial drivers are selected
- **WHEN** the initial Clan services are configured
- **THEN** `network.gateway` uses the `caddy` driver
- **AND** `persistence` uses the `postgresql` driver
- **AND** `identity` uses the `zitadel` driver
- **AND** `version-control` uses the `forgejo` driver
- **AND** `communications` uses the `matrix` driver
- **AND** `media` uses the `jellyfin` driver
- **AND** `observability` uses the `grafana` driver
- **AND** `backup` uses the `borg` driver

#### Scenario: Invalid driver settings are rejected
- **WHEN** settings are provided for a driver-backed service
- **THEN** only settings valid for the selected driver are accepted by the service interface

### Requirement: Identity separation of concerns
The identity service SHALL own identity provider runtime and reconciliation concerns while workload services retain ownership of their application-level identity needs.

#### Scenario: Identity provider is configured
- **WHEN** the identity service is configured for this change
- **THEN** it provides Zitadel runtime and reconciliation behavior
- **AND** it does not implement Himmelblau integration

#### Scenario: Workload declares identity needs
- **WHEN** a workload requires OIDC client configuration
- **THEN** the workload's identity needs can be expressed separately from Zitadel internals
- **AND** the workload can receive `identity.provider` material through settings
- **AND** identity projects decide which exported application declarations are materialized through `consumers`

### Requirement: Community-service-ready boundaries
Clan services created or reshaped by the migration SHALL avoid repository-specific assumptions in reusable service implementations.

#### Scenario: Personal configuration remains in instances
- **WHEN** a service needs personal domains, machine placement, user data, or secret prompts
- **THEN** those values are supplied through instance settings or explicit inputs
- **AND** they are not hardcoded into the reusable service implementation

#### Scenario: Service can be extracted
- **WHEN** a migrated service implementation is reviewed for extraction
- **THEN** its reusable interface and implementation are separable from this repository's local inventory choices

### Requirement: Driver-backed service implementations are isolated
Driver-backed Clan services SHALL isolate concrete driver interface, export, and NixOS implementation details from generic service wiring by using service-owned driver files.

#### Scenario: Communications Matrix implementation is isolated
- **WHEN** the communications service uses the `matrix` driver
- **THEN** Matrix-specific settings type, exports, Synapse, bridge, LiveKit, TURN, and related NixOS module configuration lives under the communications driver implementation rather than directly in the service wiring layer

#### Scenario: Service wiring avoids driver details
- **WHEN** a driver-backed service `default.nix` is reviewed
- **THEN** concrete driver interface, export fragments, and runtime configuration are loaded through driver files rather than embedded directly in the service wiring layer
