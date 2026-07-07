## ADDED Requirements

### Requirement: Service taxonomy
The migration SHALL classify service work into foundational services, generic workload services, concrete suite services, dropped legacy services, and deferred non-service concerns.

#### Scenario: Foundational services are identified
- **WHEN** the migration catalog is reviewed
- **THEN** `gateway`, `persistence`, `identity`, `observability`, and `backup` are treated as foundational services

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
Clan service instances SHALL use explicit inputs and settings for cross-service composition, with the consumer of the service instances owning the wiring.

#### Scenario: Service consumes another service explicitly
- **WHEN** a service requires a capability provided by another service instance
- **THEN** the required capability is passed through the consuming service instance settings or declared inputs
- **AND** the consuming service does not implicitly discover the provider service

#### Scenario: Service remains a black box
- **WHEN** a Clan service is implemented
- **THEN** it exposes documented inputs and outputs
- **AND** it does not rely on hidden dependencies or implicit side effects from unrelated services

### Requirement: Driver-specific settings
Generic Clan services SHALL expose a `driver` option when the service capability can have multiple concrete implementations, and the accepted settings SHALL be shaped by the selected driver.

#### Scenario: Initial drivers are selected
- **WHEN** the initial Clan services are configured
- **THEN** `identity` uses the `zitadel` driver
- **AND** `version-control` uses the `forgejo` driver
- **AND** `communications` uses the `matrix` driver
- **AND** `media` uses the `jellyfin` driver

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
- **AND** the composition layer decides whether those needs are passed to the identity instance

### Requirement: Community-service-ready boundaries
Clan services created or reshaped by the migration SHALL avoid repository-specific assumptions in reusable service implementations.

#### Scenario: Personal configuration remains in instances
- **WHEN** a service needs personal domains, machine placement, user data, or secret prompts
- **THEN** those values are supplied through instance settings or explicit inputs
- **AND** they are not hardcoded into the reusable service implementation

#### Scenario: Service can be extracted
- **WHEN** a migrated service implementation is reviewed for extraction
- **THEN** its reusable interface and implementation are separable from this repository's local inventory choices
