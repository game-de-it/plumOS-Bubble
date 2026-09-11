# Bubble final candidate: SYS-slot hardware limitation

Date: 2026-09-11

## Observation and scope

The maintainer reported that the target Bubble's **top-edge SYS microSD slot is
physically broken**. The bottom-edge SD2 slot is a separate optional ROM/BIOS
slot and cannot boot or substitute for SYS.

Consequently, no further device write/readback, cold-boot repetition or physical
acceptance can be collected from this unit. This is a hardware limitation, not
evidence of a newly observed image failure.

## Evidence that remains valid

Earlier physical results tied to their recorded builds remain valid, including
frontend/emulator lifecycle, input, Wi-Fi, sleep, speaker/headphone routing,
shutdown, SD2, representative runtime acceptance, GGFE and Game Gear shader work.
The physically accepted Clang YabaSanshiro correction is recorded separately.

Those component results do **not** prove that a later aggregate image was written
and booted. The most recent image has host-side content and filesystem verification
recorded in `2026-09-11-bubble-release-candidate-image.md`; its own final physical
gate remains unavailable on this device.

## Release handling

- Keep `BUB-P7-06` open because the exact candidate lacks final SD write/readback
  and complete physical acceptance.
- Keep `BUB-P7-07` open until the maintainer explicitly accepts the disclosed
  candidate risk.
- Keep `BUB-P7-08` open until explicit publication approval and public-asset
  checksum readback.
- Release notes must state that the final aggregate candidate was mechanically
  verified but could not be booted after the SYS-slot failure.
- Do not publish as part of documentation preparation.
