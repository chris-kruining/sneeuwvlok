## ADDED Requirements

### Requirement: Driver files expose interface and role fragments
Driver-backed Clan services SHALL place concrete driver interface, export fragments, and NixOS module fragments in `clanServices/<service>/drivers/<driver>.nix`.

#### Scenario: Driver interface exists
- **WHEN** a driver-backed service has a configured driver named `matrix`
- **THEN** the service can load the driver-specific settings type from `drivers/matrix.nix` at attribute `interface`

#### Scenario: Default role driver fragments exist
- **WHEN** a driver-backed service has a `default` role and a configured driver named `matrix`
- **THEN** the service can load export and NixOS fragments from `drivers/matrix.nix` at `roles.default`

#### Scenario: Future role driver module exists
- **WHEN** a driver-backed service later adds another role
- **THEN** the service can select the implementation from the configured driver's matching `roles.<roleName>` attribute

### Requirement: Service default owns wiring and merge composition
Driver-backed Clan service `default.nix` files SHALL own service manifest declaration, driver discovery, shared interface assembly, role wiring, common fragments, and driver/role dispatch while driver files provide driver-specific interface, export fragments, and NixOS module fragments.

#### Scenario: Service selects configured driver
- **WHEN** a service instance configures a driver
- **THEN** the service `default.nix` selects the corresponding driver file and requested role attribute

#### Scenario: Driver file stays implementation-focused
- **WHEN** a driver file is reviewed
- **THEN** it contains driver-specific interface and role fragments rather than service manifest or role declaration

### Requirement: Driver dispatch helper returns merge fragments
The shared Clan service library SHALL provide a helper that selects a service driver and role, invokes the selected role fragment functions with supplied arguments, and returns export and NixOS module fragment lists suitable for appending to lists passed to `mkMerge`.

#### Scenario: Driver helper appends to mkMerge list
- **WHEN** a service builds `config = mkMerge (...)`
- **THEN** it can append the helper result to its common fragment list

#### Scenario: Selected role fragments receive arguments
- **WHEN** the helper selects a driver role
- **THEN** it invokes that role's export and NixOS fragment functions with the arguments supplied by the service

#### Scenario: Export and NixOS fragments are mergeable
- **WHEN** the selected role returns export and NixOS module fragments
- **THEN** the helper returns those fragments as lists that can be appended to common service fragments

### Requirement: Driver discovery derives drivers from files
The shared Clan service library SHALL provide a helper that can discover driver files from a service-owned `drivers` directory.

#### Scenario: Driver files are discovered
- **WHEN** a service has regular `.nix` files under `clanServices/<service>/drivers`
- **THEN** the discovery helper imports and applies those files with supplied pure arguments into a driver attrset keyed by file basename

#### Scenario: Driver enum can use discovered names
- **WHEN** a service assembles its interface
- **THEN** it can derive the accepted driver enum from the discovered driver attr names

### Requirement: Driver top-level evaluation is interface-safe
Driver files SHALL keep top-level evaluation free of NixOS `config`, role settings, `pkgs`, and per-instance values so driver interfaces can be loaded while assembling service options.

#### Scenario: Interface is evaluated before role execution
- **WHEN** a service assembles its driver-backed interface from discovered drivers
- **THEN** each driver's top-level `interface` can evaluate using only the pure arguments supplied by driver discovery

#### Scenario: Runtime values stay inside role fragments
- **WHEN** a driver needs NixOS `config`, `pkgs`, role settings, or per-instance values
- **THEN** it reads them inside `roles.<roleName>.exports` or `roles.<roleName>.nixosModules` rather than at driver file top level

### Requirement: Missing driver or role reports clear errors
The shared Clan service driver helper SHALL fail evaluation with an explicit error when the selected driver or role attribute is missing.

#### Scenario: Missing driver
- **WHEN** a service selects a driver that is not present in its loaded driver set
- **THEN** evaluation fails with an error that names the service, selected driver, available drivers, and expected driver file shape

#### Scenario: Missing role
- **WHEN** a service selects a role that is not exposed by the selected driver file
- **THEN** evaluation fails with an error that names the service, selected driver, requested role, available roles, and expected role attribute shape

### Requirement: Driver helper is available to path-registered services
The shared Clan service driver helper SHALL be exposed through the shared `ardaLib` passed to path-registered Clan service modules.

#### Scenario: Communications service resolves helper
- **WHEN** the communications service dispatches its configured driver role
- **THEN** it can call the shared driver helpers through `ardaLib.clanServices`
