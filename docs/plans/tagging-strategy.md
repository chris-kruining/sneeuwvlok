# Clan machine tagging strategy

## Goal

Replace machine-name targeting with stable tags that survive machine renames, hardware reshuffles, and service moves.

The strategy should fit how this repo is evolving:

- machine tags should describe the machine
- service roles should describe service topology
- computed tags should be derived from machine settings or other explicit metadata, not from other tags

## Source material

This plan is based on:

- current Clan inventory in `clan.nix`
- current machine configs under `machines/*/configuration.nix`
- workload and module usage on `main` under:
  - `systems/x86_64-linux/*/default.nix`
  - `homes/x86_64-linux/chris@*/default.nix`
- Clan inventory tag and dynamic-tag documentation

## Guiding principles

### 1. Prefer capabilities over roles

A machine rarely has one permanent role. In this repo especially, a machine may be interactive, portable, build-capable, and temporarily host some service at the same time.

Because of that, tags should describe durable traits and capabilities rather than trying to answer "what is this machine?"

### 2. Do not encode current workload as a machine tag

A machine currently running Grafana, Jellyfin, or PostgreSQL does not mean that those should become machine tags. Those are current placements, not stable identity.

If a service can move, its current presence is weak evidence for tagging.

### 3. Use service roles for topology

Some relationships belong in service definitions rather than host tags.

Examples:

- NFS producer and consumer
- persistence provider and client
- reverse proxy frontend and backend

These are not machine identity tags; they are service-topology relationships.

### 4. Derive tags from settings when possible

If a machine setting already captures a fact, derive the tag from that setting instead of duplicating it by hand.

Good examples in this repo:

- `desktop.use` can imply whether a machine is interactive
- `hardware.has.gpu.*` can imply GPU availability
- `hardware.has.audio` can imply audio capability
- `hardware.has.bluetooth` can imply Bluetooth capability

### 5. Avoid deriving tags from other tags

Clan supports dynamic tags, but tag-from-tag derivation can become fragile and can even recurse. If tags need computation, compute them from machine settings or an explicit metadata source instead.

## Proposed namespaces

Use full words:

- `capability:*`
- `operational:*`

The intention is:

- `capability:*` describes stable machine traits
- `operational:*` describes automation-relevant policy or availability behavior

## Capability tags

These are the strongest candidates for machine tags.

### Runtime

- `capability:runtime:interactive`
- `capability:runtime:headless`

These are directly useful for deciding where a service with a user-facing local experience does or does not belong.

### Hardware

- `capability:hardware:gpu`
- `capability:hardware:audio`
- `capability:hardware:bluetooth`

At the moment, the repo provides enough configuration structure to derive these from machine settings.

GPU vendor-specific tags are intentionally excluded for now. The current conclusion is that the presence of GPU hardware may matter, but the vendor usually does not unless there is a specific workload that depends on CUDA, ROCm, or a similar stack.

### Mobility

- `capability:mobility:portable`
- `capability:mobility:stationary`

These are useful concepts, but they are not currently obvious from one uniform machine setting in the repo. If they become desirable, they likely need either:

- an explicit machine setting, or
- a stronger convention around machine form factor

For now they are candidates, not automatic defaults.

## Operational tags

Operational tags are weaker than capability tags and should stay small in number.

They should only exist when they capture real automation constraints that are not already represented elsewhere.

### Availability

- `operational:availability:always-on`
- `operational:availability:wake-on-demand`
- `operational:availability:manual`

This dimension became clearer while thinking through the Mandos build-host idea. A machine may be technically capable of a workload, while its availability policy determines whether it is a sensible target.

These tags should not be guessed from existing workloads. They should come from an explicit machine setting that states the intended availability policy.

### Interruptibility

- `operational:workload:interruptible`

This is not about the machine by itself. It is a useful policy boundary for selecting machines that may host work that can be delayed, retried, paused, or moved.

If introduced, it should again come from explicit machine policy rather than being inferred from current services.

## What should not become machine tags

- current service assignments, such as Jellyfin, Grafana, Forgejo, or PostgreSQL
- service topology, such as NFS producer or consumer
- user application presence, such as Discord or TeamSpeak
- detailed desktop-environment choice, such as Plasma or Gamescope
- one-off descriptions like "living room" unless location becomes a deliberate scheduling dimension

## What is derivable today

The repo already contains enough structure to derive several useful capability tags.

Examples from the current configuration style:

- if a machine enables a desktop session, derive `capability:runtime:interactive`
- if a machine does not, derive `capability:runtime:headless`
- if a machine enables `hardware.has.audio`, derive `capability:hardware:audio`
- if a machine enables `hardware.has.bluetooth`, derive `capability:hardware:bluetooth`
- if a machine enables any `hardware.has.gpu.*`, derive `capability:hardware:gpu`

## What probably needs explicit policy

These should not be inferred from current services or tag combinations:

- `operational:availability:*`
- `operational:workload:interruptible`
- mobility-related tags if there is no explicit machine setting to derive them from

The clean way to support these is to introduce one or more explicit machine settings whose purpose is to describe machine policy rather than workload.

## Mandos update

The Mandos wake-on-demand build-host idea adds an important refinement:

- some machines should be eligible for background work only when they are available through a specific policy, such as wake-on-demand

This does **not** mean Mandos should get a hand-maintained "build server" tag.

It instead suggests a more generic pattern:

- a machine may be interactive
- a machine may be available on demand rather than always on
- that availability policy may influence whether certain classes of automation should target it

That strengthens the case for a very small `operational:*` namespace derived from explicit machine policy.

## Recommended next steps

1. Start with `capability:*` tags that are clearly derivable from machine settings.
2. Keep service topology in service roles instead of machine tags.
3. If availability policy becomes important, add an explicit machine setting for it and derive `operational:*` tags from that setting.
4. Avoid expanding the tag vocabulary until there is a clear service-selection use case for each added tag.
