# Mandos as a wake-on-demand build host

## Goal

Mandos is primarily an interactive living-room machine, but it is also a strong candidate for handling remote Nix builds when it is idle. The goal is to make that dual use practical without keeping the machine powered all the time.

## Current context

On `main`, Mandos is configured as an interactive gaming machine:

- `systems/x86_64-linux/mandos/default.nix`
  - `sneeuwvlok.hardware.has.gpu.nvidia = true`
  - `sneeuwvlok.hardware.has.audio = true`
  - `sneeuwvlok.desktop.use = "gamescope"`
  - `sneeuwvlok.application.steam.enable = true`
- `homes/x86_64-linux/chris@mandos/default.nix`
  - user-facing application set for an interactive machine

This makes Mandos a poor fit for "always running random infrastructure", but a reasonable fit for "available for work when needed".

## Desired behavior

- Mandos remains an interactive machine first.
- Mandos can be used as a remote build worker when no one is actively using it.
- Mandos should not need to stay fully on all day just to be eligible for builds.
- Waking and idling down should be automatic enough that the machine can participate in builds without turning into a maintenance burden.

## Recommended model

### 1. Use wake-on-LAN as the activation mechanism

Mandos should support being awakened by another machine on the same LAN.

Requirements:

- BIOS or UEFI wake-on-LAN support enabled
- NixOS interface configuration enabling wake-on-LAN
- one low-power machine that is effectively always available to send wake requests

In this repo, `ulmo` is the obvious candidate to act as the coordinator, but the pattern should stay generic: one machine is always reachable, and one or more stronger machines can be woken on demand.

### 2. Prefer suspend-first over shutdown-first

There are two main power states worth considering:

- **Suspend on idle**
  - faster resume
  - generally better user experience
  - often easier to make reliable for wake-on-LAN
- **Shutdown on idle**
  - lowest power draw
  - more fragile in practice because firmware support for wake from soft-off varies
  - longer time to become available again

Recommended rollout order:

1. Prove the concept with suspend on idle.
2. Only consider full power-off later if the hardware and firmware behave reliably.

## 3. Add an explicit availability policy

The interesting lesson for tagging is not "Mandos should have a build tag". The interesting lesson is that some machines have a deliberate availability policy that affects how safely they can participate in automation.

A future host-level setting could encode this policy directly, for example:

- `always-on`
- `wake-on-demand`
- `manual`

That setting would be a better source for any computed operational tag than current workload or ad hoc tags.

## 4. Idle detection should be policy-driven

If Mandos becomes a build worker, idle shutdown or suspend should depend on signals such as:

- no local interactive session activity
- no active build job
- no long-running system task that should keep the machine awake

This should not be a blind timer that powers the machine down every X minutes regardless of context.

## 5. Build orchestration needs a coordinator

Wake-on-demand only works well if something else can wake the machine and wait for it to become reachable. In practice, this means:

- a coordinator sends the wake signal
- the build client retries until the machine is reachable
- the remote builder participates only after it is actually ready

The exact implementation can vary, but the architectural point is the same: a wakeable build worker is not self-sufficient.

## Risks and caveats

- Firmware wake support may be unreliable, especially from full shutdown.
- Build latency increases because wake and readiness checks take time.
- A machine that users expect to be immediately available should not surprise them with power-state transitions at awkward moments.
- Interactive workload detection matters; otherwise the machine will feel hostile as a living-room device.

## Recommendation

Treat the Mandos idea as a good pattern, but generalize it:

- some machines are **interactive**
- some machines are **wakeable on demand**
- some machines are suitable for **interruptible background work**

Those are more reusable concepts than "Mandos is the build server".

## Implications for the tag strategy

This investigation strengthens a small part of the `operational:*` space:

- `operational:availability:always-on`
- `operational:availability:wake-on-demand`
- `operational:workload:interruptible`

These should not be assigned by hand if they can instead be computed from explicit machine settings that describe availability policy.

## References

- Clan inventory tags and dynamic tags docs: `https://clan.lol/docs/25.11/reference/options/clan_inventory`
- NixOS Wake-on-LAN wiki: `https://wiki.nixos.org/wiki/Wake_on_LAN`
- Home-lab wake-on-demand discussion and patterns:
  - `https://dgross.ca/blog/linux-home-server-auto-sleep`
  - `https://danielpgross.github.io/friendly_neighbor/howto-sleep-wake-on-demand.html`
