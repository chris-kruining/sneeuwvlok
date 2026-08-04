## ADDED Requirements

### Requirement: Driver-backed service implementations are isolated
Driver-backed Clan services SHALL isolate concrete driver interface, export, and NixOS implementation details from generic service wiring by using service-owned driver files.

#### Scenario: Communications Matrix implementation is isolated
- **WHEN** the communications service uses the `matrix` driver
- **THEN** Matrix-specific settings type, exports, Synapse, bridge, LiveKit, TURN, and related NixOS module configuration lives under the communications driver implementation rather than directly in the service wiring layer

#### Scenario: Service wiring avoids driver details
- **WHEN** a driver-backed service `default.nix` is reviewed
- **THEN** concrete driver interface, export fragments, and runtime configuration are loaded through driver files rather than embedded directly in the service wiring layer
