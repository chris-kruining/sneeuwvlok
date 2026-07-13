## ADDED Requirements

### Requirement: Services declare generated internal endpoints
The system SHALL allow Clan service implementations to declare named generated internal endpoints for NixOS service listeners without requiring bind address or concrete port values.

#### Scenario: Single service declares a generated endpoint
- **WHEN** a service declares a generated endpoint named `version-control/default/forgejo`
- **THEN** the generated endpoint claim is available to endpoint management as raw claim data

#### Scenario: Service declares multiple generated endpoints
- **WHEN** a service such as Servarr declares generated endpoints for `sonarr`, `radarr`, and `prowlarr`
- **THEN** each listener is represented as a separate generated endpoint claim

#### Scenario: Service declares auxiliary generated endpoints
- **WHEN** a service such as Servarr also needs auxiliary listeners for `sabnzbd`, `qbittorrent`, or `flaresolverr`
- **THEN** each auxiliary listener can be represented as a separate generated endpoint claim

### Requirement: Endpoint management assigns ports per machine
The system SHALL aggregate generated endpoint claims for each machine and assign unique internal ports within that machine.

#### Scenario: Multiple claims on one machine
- **WHEN** a machine has multiple enabled generated endpoint claims
- **THEN** endpoint management assigns a distinct port to each claim on that machine

#### Scenario: Same port number on different machines
- **WHEN** different machines receive generated assignments
- **THEN** the same port number MAY be assigned on different machines without conflict

### Requirement: Assignments are deterministic for a claim set
The system SHALL produce deterministic generated endpoint assignments for the same machine claim set and endpoint management configuration.

#### Scenario: Repeated evaluation
- **WHEN** the same machine has the same enabled claims and endpoint management configuration across evaluations
- **THEN** endpoint management produces the same `ports.assigned` mapping

### Requirement: Services read generated endpoints through helpers
The system SHALL expose generated endpoints through helpers that read underlying assigned ports from the `ports.assigned` export namespace.

#### Scenario: Service reads its assigned port
- **WHEN** a service needs the generated endpoint for one of its claims
- **THEN** it can read an endpoint-shaped value using the current machine and claim key

#### Scenario: Consumer uses helper for assigned port lookup
- **WHEN** a consumer needs to read a generated endpoint from Clan exports
- **THEN** the system provides a helper or documented wrapper around export lookup for reading `ports.assigned` and returning an endpoint-shaped value

### Requirement: Endpoint helpers produce endpoint-shaped values
The system SHALL expose generated listener assignments as values that conform to the shared endpoint type.

#### Scenario: Generated endpoint binds to gateway
- **WHEN** a service claims an internal listener and exports a gateway service for it
- **THEN** the generated endpoint value can be assigned directly to the gateway service endpoint option

#### Scenario: Generated endpoint exposes raw port
- **WHEN** a NixOS service module needs only the generated port number
- **THEN** the generated endpoint value exposes the assigned port through its `port` attribute

### Requirement: Endpoint values stringify consistently
The system SHALL provide stringification for shared endpoint values through the endpoint type.

#### Scenario: Endpoint used as string
- **WHEN** an endpoint value is coerced to a string
- **THEN** the result includes the endpoint protocol, host, port, path, query, and hash according to the shared endpoint stringification rules

### Requirement: Endpoint consumers use endpoint type
The system SHALL model options that accept endpoint-shaped values with the shared endpoint type.

#### Scenario: Endpoint passed between services
- **WHEN** one service exports an endpoint and another service consumes it
- **THEN** both the producing and consuming options use the shared endpoint type rather than ad hoc host/port/string options

### Requirement: Endpoint management reports range exhaustion
The system SHALL fail evaluation with a clear error when a machine has more enabled claims than the configured allocation range can satisfy.

#### Scenario: Too many claims for configured range
- **WHEN** a machine has more enabled claims than available ports in the configured endpoint management range
- **THEN** evaluation fails with an error that identifies the machine, claim count, and allocation range

### Requirement: Generated endpoints are internal wiring
The system SHALL treat generated endpoints and their generated port assignments as internal machine-local wiring rather than public addressing.

#### Scenario: Public service access
- **WHEN** a service is publicly accessible
- **THEN** public addressing is represented through gateway or service exports rather than relying on a stable generated port number

### Requirement: Endpoint management avoids cyclic export dependencies
The system SHALL derive assignments only from raw port claims and endpoint management configuration.

#### Scenario: Gateway endpoint depends on assigned port
- **WHEN** a service exports a gateway endpoint using a generated port
- **THEN** endpoint management does not read that endpoint while computing `ports.assigned`
