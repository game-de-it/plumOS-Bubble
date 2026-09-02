# Bubble cross-device guide gap audit

Date: 2026-09-02

## Scope and evidence rule

This audit compares the current Bubble repository and device evidence with
`plumOS_gitlog_problem_solution_guide.ja.md`. It does not turn host checks into
physical passes and does not interpret a visible menu item as an implemented
backend. The ROM SD, user configuration, saves, BIOS, credentials, and current
runtime state remain outside the replacement boundary.

Status meanings:

- **implemented**: repository implementation and host verification exist;
- **device partial**: at least one real-device route passed, but the guide's
  complete boundary has not;
- **open**: implementation or required physical/destructive proof is missing.

## Findings

| Guide boundary | Current Bubble evidence | Status / action |
| --- | --- | --- |
| Preserve the stock boot boundary before replacement | Stock boot artifacts, runtime DT, kernel/module/firmware inventories and matching hashes exist. Full offline recovery image, active U-Boot environment ownership, and failure rollback proof do not. | **device partial**; retain P1/P2 gates. Do not replace the preserved substrate yet. |
| Make boot/provisioning progress and failure visible | Persistent `S10..S90` stage logs and recovery SSH exist. First-boot p3 expansion/p4 creation completed, but the common logo hides progress. | **open**; V90S-style progress renderer and failure screen remain required before release. |
| Separate system, managed runtime, mutable config, and user media | Component-scoped libraries, app-layer checksums, factory defaults and active config separation exist. Live deploy preserves config hashes. | **device partial**; System A/B and final mount contract remain open. |
| Do not auto-repair dirty removable media; warn and keep it read-only | SD2 is resolved separately. Kernel reported FAT corruption. The FE exposed a Storage Check entry but its helper was absent, and the minimal System did not remount SD2 after reboot. | **implemented now, device proof pending**: packaged a guarded read-only SD2 mount and `plumos-storage-health`; startup observation records kernel errors, manual checks refuse read-write mounts and only use `fsck -n` with a timeout. |
| Fonts and other UI assets must be owned independently of ROM media | UTF-8 Japanese names are correct in `library-index.json`, but font lookup followed SD2 and fell back to built-in ASCII. | **implemented now, device proof pending**: primary/fallback fonts resolve from `/storage/plumos/fonts` first; build probes Japanese glyphs. |
| Capture physical input and preserve printed button labels | Full evdev/js identity map is recorded. PicoArch A/B, missing L3/R3 and Function1 were corrected. The user passed the PicoArch QuickNES A/B/menu/exit sequence. | **device partial**; X/Y, shoulders, both sticks, standalone layouts, volume and power remain per-route gates. |
| Validate display by renderer/content class | Software RetroArch, GLES RetroArch, PicoArch and GLES standalone processes ran. PicoArch QuickNES orientation/aspect is physically accepted. | **device partial**; vertical arcade, rotated handheld, square/wide/dual-screen, GLES and standalone classes remain separate physical gates. |
| Validate audio at the device, not only by process liveness | Several routes advanced ALSA pointers; PicoArch QuickNES sound is physically accepted. Both N64 cores remained `PREPARED` with `hw_ptr=0`. | **device partial**; N64, headphone/jack, XRUN and five-minute runs remain open. |
| Give one session one owner and restore FE/device resources after exit | PicoArch launcher has bounded TERM/KILL and child reaping; representative exits restored one FE and released ALSA. | **device partial**; all standalone/Ports/Pyxel paths and repeated-launch tests remain open. |
| Keep every system/core/route visible and prove bidirectional coverage | 98 systems, 196 profiles, 114/114 source records and visible unsupported reasons pass host checks. | **implemented on host**; all-core content/device acceptance remains open and QuickNES-only publication is rejected. |
| Use atomic, authenticated updates with rollback and preservation proof | App-layer manifests/checksums and rollback archives support controlled development deployment. | **open**; signed packages, downgrade rejection, System A/B slot health, interrupted update, bad-slot recovery and disk-full tests are not implemented. |
| Reproduce from a clean clone and run publication gates | Container builds and many host verifiers exist; current retained image predates later live commits. | **open**; clean-clone image rebuild, license/source completeness, secret/ROM/BIOS scan, media readback and cold-boot repetition remain release gates. |

## Immediate changes in this pass

1. Correct managed font ownership and assert Japanese glyph coverage during the
   Bubble frontend build.
2. Log the selected primary and fallback font at FE startup so a future failure
   can be distinguished from malformed filenames.
3. Implement the previously missing storage-health backend without any repair
   mode, and observe dirty-media evidence before and after the library scan.
   A mounted SD2 also overrides the supervisor's generic `/storage` default.
   Passive observation cannot clear a dirty result, and boot preserves a
   completed index instead of repeatedly scanning known-dirty media.
4. Record the user's physical PicoArch QuickNES input/display/audio acceptance
   without extending that result to untested routes.

## Remaining implementation order

1. Make first-boot provisioning progress and failure visible using the common
   plumOS design while preserving the proven partition transaction.
2. Fix and physically re-test N64 audio before treating the GLES RetroArch class
   as accepted.
3. Execute the display/input/audio matrix by renderer class and keep unsupported
   paths visible with reasons.
4. Complete boot recovery ownership, signed System A/B update, interruption and
   rollback proof before release-candidate image work.
5. Rebuild from a clean clone, run contamination/license gates, write/read back,
   and require explicit user acceptance before publication.
