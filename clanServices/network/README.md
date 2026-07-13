# Network

Provides generated internal endpoints for services and public ingress.

The `default` role assigns machine-local generated internal endpoint ports from raw `ports.claims` and exports `ports.assigned`.

The `gateway` role renders public ingress from explicit route, service, function, and host settings. Gateway route and service exports must not feed endpoint allocation.
