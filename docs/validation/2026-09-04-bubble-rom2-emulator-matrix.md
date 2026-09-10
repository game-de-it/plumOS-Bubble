# Bubble ROM2 emulator matrix (2026-09-04)

## Scope

The device's current SD2 library and the supplied read-only Mac ROM set at
`/Volumes/public/02/motoki/emu/ROM/rom2` were used to exercise every one of the
98 visible systems and 196 launch-profile occurrences. No catalog route was
removed. ROM2 content needed by the matrix was copied into the isolated device
validation area under `/storage/plumos/state/device-matrix`; the source ROM set
and the read-only SD2 were not modified.

Persistent volume, runtime volume and ALSA softvol were held at zero. Runtime
config, saves and states were isolated with temporary bind mounts. The harness
also held the frontend supervisor while a route owned display/audio and restored
one normal frontend process after the matrix.

The latest-record aggregate is:

| State | Routes | Result |
|---|---:|---|
| started | 168 | bounded process lifetime, display ownership and clean harness teardown |
| failed | 3 | runtime or compatible-content failure described below |
| not run | 24 | no compatible content in either available set, or external content route |
| visible unsupported | 1 | DraStic remains visible but Bubble lacks its required input bridge |

The machine-readable aggregate is
`artifacts/device-validation/2026-09-04-bubble-emulator-device-matrix-consolidated.json`.
It was produced in report order from the full scan and subsequent recovery,
renderer and vertical-arcade retests; a later row supersedes the same
system/profile row from an earlier report.

## Current SD2 versus ROM2

The first full scan used the current frontend library, including SD2 paths.
Forty failed `live_library` routes across Dreamcast, Game Gear, Master System,
Mega Drive, NES, PC Engine, PC Engine CD, Pico-8, PS1, Saturn and WonderSwan
subsequently started when the same launchers/cores were given ROM2 validation
copies. Three other initial failures were also cleared by repeat or replacement
content. This isolates those failures from the emulator binaries and is
consistent with the already-observed read errors on the dirty, read-only FAT
media. It does not authorize or perform an SD2 repair.

The content map references 63 unique validation paths. Sixty-two are byte-for-byte
SHA-256 matches to source ROM2 files. The remaining `sky.scummvm` is a generated
ScummVM target pointer beside unchanged ROM2 game data. Validation content uses
about 1.5 GiB and staged BIOS content about 153 MiB on the device.

## Remaining failures and unavailable routes

The three executable failures are:

- `cps2 / retroarch:fbalpha2012_cps2`: the supplied clone and validation parent
  aliases still lack ROM CRC `0xcf94d275` required by this older core. The same
  CPS2 content family starts through FBNeo and generic FBA2012; the dedicated
  profile stays visible and failed.
- `msx / retroarch:bluemsx`: exits with signal 11 after video/audio/input
  initialization. The visible fMSX fallback starts successfully.
- `colecovision / retroarch:bluemsx`: the same BlueMSX signal-11 failure; this
  system currently has no second catalog profile.

The one hardware-visible unsupported route is
`nds / standalone:drastic`, because Bubble has no `/dev/miyooio` input bridge.

The 24 unexecuted routes remain visible. One is an implementation gap rather
than missing content: `2048 / retroarch:2048` is a no-content core, but the
Bubble launcher rejects `--no-content` with exit 2. No app-layer change was
made during this validation task.

The other 23 content-unavailable routes are:

- NGP, WonderSwan Color, Ports, X68000, TIC-80, Vectrex, BK, Daphne,
  Flashback, Mr.Boom, Palm, Rick Dangerous, Sharp X1, Wolf3D and ZX81: one route
  each.
- SG-1000: BlueMSX, Gearsystem, Genesis Plus GX and PicoDrive (four routes).
- Arduboy, Mega Duck, PuzzleScript and Super Bros War: one route each.

NGP specifically has an unreadable SD2 archive and no clean monochrome NGP
sample in ROM2. A second ROM2-wide filename/extension search found no additional
compatible sample for these systems. The only matching files were the NGP BIOS,
the already-tested Dinothawr `.game`, and an Uzebox `.hex` used by another
system.

## Display and renderer contracts

The active RetroArch contract was captured as Ozone + GL, Core Provided aspect,
forced aspect preservation, integer scale off and user rotation zero. Of 168
started routes, 123 emitted usable runtime geometry: 112 horizontal and 11
vertical. Every calculated viewport was centered and bounded within the
640x480 panel.

The Varth vertical retest started all nine Arcade/CPS1 profiles. Eight emitted
an explicit 3:4 geometry contract and calculated a centered 360x480 viewport,
including generic FBA2012, dedicated FBA2012 CPS1 and MBA Mini. MAME2003 Plus
started with display and audio ownership but emitted no geometry line, so its
final pixel orientation still requires physical LCD observation.

Renderer inspection found 128 started routes with the Bubble Mali mapping and
40 CPU-framebuffer routes with no GL mapping. No started route mapped llvmpipe,
softpipe, `swrast_dri` or `kms_swrast`. Standalone PCSX-ReARMed intentionally
uses its built-in AArch64 NEON GPU path rather than a Mesa software fallback.
Standalone PPSSPP started on Mali and owned DRM/audio, but logged Thin3D shader
link failures; this remains a renderer warning rather than a clean visual pass.

## Audio contract

ALSA hardware-pointer progress was observed continuously for 163 of the 168
started routes. The following five started and held display ownership but did
not advance PCM during the bounded sample:

- Atari 800 / Atari800
- Channel F / FreeChaF
- J2ME / SquirrelJME
- TI-83 / Numero
- VMU / VeMUlator

Because requested volume was zero, this proves audio-stream activity only. It
does not prove speaker output or subjective sound correctness. Those five
routes, PPSSPP visual output, the 45 routes without geometry logs, and every
route's physical controls/return path remain device-observation acceptance.

### 2026-09-10 bounded physical audio follow-up

The first `tents_CF.bin` run entered RetroArch's dummy-core menu immediately.
The route and content path were correct, but the log showed that FreeChaF had
fallen back to its experimental HLE BIOS and stopped on unsupported function
`0xd0`. Existing user-owned `sl31253.bin` and `sl31254.bin` images were found
outside this repository, matched the core-info MD5 values, and were copied only
to the device-owned BIOS directory. No BIOS was added to the repository or
managed application layer.

On the next normal FE launch, the log requested only the optional Channel F II
BIOS, initialized 306x192 at 60 Hz and 44100 Hz audio, and did not report the
HLE error. The user confirmed that the game started and that controls and
speaker audio were normal. FreeChaF physical audio is accepted. Source
`0b6d144` also disables the dummy-core fallback for bounded FE-launched
RetroArch sessions, so a future core-requested shutdown returns display
ownership to the FE instead of exposing an empty RetroArch menu. The deployed
frontend component passed 218 checks and the complete application layer passed
12,461 checks; rollback material is retained under
`state/app-deploy/0b6d144-freechaf/`.

The supplied VMU `ANIMTEST.VMI` is only a 108-byte Dreamcast transfer descriptor;
its referenced `ANIMTEST.VMS` executable payload is absent. The pinned VeMUlator
core advertises only `vms`, `bin`, and `dci`, so exposing `vmi` in the Bubble FE
created a selectable item that could never exercise the runtime. The catalog now
matches the core contract and excludes `vmi`. The original device-owned descriptor
is preserved. Physical audio acceptance still requires a valid sound-producing VMU
program launched through the normal FE route.

For physical audio acceptance, the openly published SoundDemo VMS was staged
temporarily in the device-owned ROM area and discovered as the only valid VMU
item. The normal FE route launched VeMUlator at 48x32, 60 Hz and 32768 Hz. ALSA
was `RUNNING`, with `hw_ptr=611472` and `appl_ptr=613813`, and the user confirmed
that the buzzer beep was audible through the speaker. VeMUlator physical audio
is accepted. The test VMS is not part of the managed application layer and is
removed after the runtime exits.

Atari800 initially reached Yoomp's own `computer crashed` screen rather than
terminating. The first run also exposed an independent integration fault:
Atari800 attempted to create `/root/.atari800.cfg` on StockOS's read-only root,
then kept consuming CPU while ALSA remained in XRUN. The launcher now gives each
RetroArch system a writable HOME below `state/retroarch/`. Bubble also adopts
the established A30 per-system Atari800 options without overwriting an existing
user `.opt`: Atari 8-bit uses PAL with Modern XL/XE 1088K, while Atari 5200 uses
NTSC with the 5200 machine profile.

With the corrected route, Yoomp ran normally for more than 46 seconds at
336x240, 59.92 Hz and 44100 Hz. The user confirmed normal speaker audio. This
accepts Atari800 and completes the deliberately narrowed physical-audio matrix;
Numero was classified audio-inapplicable from source, while FreeChaF and
VeMUlator were physically accepted separately.

## Reports and device post-condition

Source reports, in merge order:

- `2026-09-04-bubble-all-content-device-matrix.json`
- `2026-09-04-bubble-recovery-retest.json`
- `2026-09-04-bubble-standalone-renderer-retest.json`
- `2026-09-04-bubble-vertical-arcade-retest.json`
- `2026-09-04-bubble-termination-retest.json`

After teardown the device had exactly one frontend process, no validation hold
or bind mounts, no game DRM/audio owner, persistent/runtime volume `0`, softvol
raw `0,0`, and unchanged frontend/system settings hashes. SD2 remained mounted
read-only. Five orphaned RetroArch zombie entries from the earlier group-wide
bounded termination remain under stock PID 1; they own no file descriptors and
cannot be killed, so a later normal reboot is required to reap them. The harness
now terminates the launcher first so it can reap its emulator child before any
process-group escalation. No release was published.

## Same-day remediation

The executable implementation gaps were addressed without removing any route.
The updated latest aggregate is 173 started routes, one failed route, 22 routes
without compatible content, and zero routes marked hardware-unsupported.

- The launcher now supports no-content cores. Both 2048 and Mr.Boom passed the
  bounded DRM/audio/process probe.
- A BlueMSX core dump showed that `Auto` selected the stripped, non-redistributable
  MSX2+ BIOS profile. Machine creation freed the CPU object, but the core still
  reported a successful load and entered it on the first frame. The reproducible
  core build now selects the packaged C-BIOS profiles and reports machine-start
  failure instead of entering a stale CPU pointer. MSX passed with packaged C-BIOS;
  ColecoVision passed after staging the BIOS already present in the supplied ROM2
  set as user validation data. The proprietary Coleco BIOS was not added to the
  app layer.
- DraStic no longer uses the copied MF `/dev/miyooio` gate. Bubble uses the
  steward-fu/nds GKD MiniPlus AArch64 GLES runner, `/dev/input/event2`, and an
  ARMHF DraStic core. The bounded probe passed process lifetime, Mali/DRM ownership
  and advancing ALSA PCM. Physical dual-screen layout, controls, Function1 menu
  and normal exit/FE return still require observation on the handheld.
- The supplied `ssf2tu-2010` content starts with FBNeo and generic FBA2012 when
  exposed under its expected archive name. The dedicated FBA2012 CPS2 core still
  requests CRC `cf94d275`; that CRC is absent from all ZIP entries under ROM2's
  `fbneo` and `mame` trees. This is a ROM-set generation mismatch, not a remaining
  Bubble launcher/core crash, and the dedicated route remains visible.

Remediation evidence is recorded in `artifacts/device-validation/` under
`bubble-remediation-*.json`. Persistent/runtime volume remained at zero during
the probes. No release was published.
