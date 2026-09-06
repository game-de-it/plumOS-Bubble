# Bubble GGFE span-raster device validation (2026-09-06)

## Scope

Commit `7b208dd` replaces triangle bounding-box walks with scanline spans and
steps perspective terms across each span.  This validation measured the new
rasteriser on the physical Bubble during continuous carousel motion and the
launch animation, then exercised the normal RetroArch return path.

The checked-in output initially carried the previous `ad12c38` source ref.
It was rebuilt from `7b208dd` before deployment.  The resulting AArch64
`bin/plumos-ggfe` was 68,496 bytes with SHA-256
`4ce5f333ed22d0d3c120af0207a825d1b187e43402a715d85a99441115446071`.

## Deployment and display ownership

The complete 212-entry frontend component was staged under
`/storage/plumos/.incoming/7b208dd-ggfe-span/`.  Its transfer archive and
component checksums passed before the atomic switch.  The component manifest,
component checksum file, and the corresponding 213 app-layer checksum entries
were updated together.  Frontend settings, system settings, and core overrides
retained their pre-deployment hashes.

Rollback is available at:

```text
/storage/plumos/state/app-deploy/7b208dd-ggfe-span/rollback.tar
SHA-256 2e768dbc094cb8c0625a39b72644fa0cd9798b51ec660ef817573f64bcf45f83
```

`/run/plumos/validation/frontend-hold` was created before the existing frontend
was terminated once.  The replacement `plumos-frontend-launch` entered the
hold, and `plumos-ggfe` was then started directly as the only renderer.  This
avoided simultaneous FE/GGFE drawing and did not consume repeated early-init
retries.

## Performance result

The device used the expected DRM path:

```text
ggfe_renderer=ready backend=drm xres=640 yres=480 bpp=32 shadow=0 double_buffer=1
```

During sustained D-pad scrolling the measured ranges were:

- frame rate: approximately 11.0 to 14.3 fps
- compose average: approximately 57 to 71 ms, commonly 63 to 68 ms
- blit average: approximately 2.2 ms
- present average: approximately 6 to 10 ms

A representative scrolling interval was:

```text
ggfe_frames=fps=12.00 frames=12 elapsed_ms=1000 max_frame_ms=133 slow_frames=12 compose_us=65560/84302 blit_us=2307/3055 present_us=6986/14854
```

The later launch-animation interval reached about 21 fps with a 38.5 ms
compose average:

```text
ggfe_frames=fps=21.00 frames=21 elapsed_ms=1000 max_frame_ms=67 slow_frames=21 compose_us=38525/62991 blit_us=2372/3893 present_us=6710/15639
```

The span rasteriser is therefore a measurable but insufficient physical-device
improvement over the earlier roughly 9.8 to 13.3 fps result.  The panel
conversion and DRM page flip remain small; `compose_us` is still 3.5 to 4.3
times the 16.6 ms 60 fps budget during scrolling.  The next optimisation must
reduce compose work, with `-DGGFE_PROFILE` available to split clear, opaque
cart, translucent glass, console, and HUD time on the device.

## Launch, return, and teardown

Physical A generated code 305 and launched `Super Monaco GP.gg` through
`retroarch:genesis_plus_gx`.  RetroArch returned successfully:

```text
ggfe_launch=done status=0
```

GGFE reacquired DRM (no `ggfe_renderer=reacquire-failed` was recorded), but the
first test showed that the RetroArch SELECT+START exit chord remained queued on
the evdev fd that GGFE had kept open during the child process.  Immediately
after `ggfe_launch=done`, two `ggfe_input=exit code=315 physical=START` records
caused an unintended GGFE exit.

Commit `e7b08d9` closes GGFE's input fd before handing control to the emulator
and opens a fresh fd after return.  The complete 212-entry frontend component
was rebuilt and deployed with matching component/app-layer metadata.  Its
device binary SHA-256 was
`675bcd6873c0bd15da315cb656281f0c4a07c593182b21c870cae8b7c1dd5ead`.
The physical retest launched `Pengo.gg`, exited RetroArch with SELECT+START,
and recorded:

```text
ggfe_launch=done status=0
ggfe_input=reopened-after-launch
ggfe_scroll=start from=3 to=4 duration_ms=360
```

No `ggfe_input=exit` followed the RetroArch exit chord.  Physical D-pad input
continued to move the carousel, proving that GGFE retained control after the
game.  Physical B then produced code 304 and `ggfe_exit=ok`, returning through
the normal Apps route to the frontend.

The validation hold was removed and the normal frontend returned after three
seconds.  Final state was exactly one
`plumos-controller-ui-fbdev`, no GGFE or RetroArch process, no validation hold,
valid frontend component checksums, and unchanged mutable configuration.

The physical appearance of the improved motion has not been accepted and the
60 fps gate remains open.  Post-game input isolation is accepted.

## Four-core stripe follow-up

Commit `bcaa959` adds a four-core worker pool.  Twenty-four horizontal stripes
are claimed dynamically so the centre-heavy cartridge scene does not leave the
top and bottom workers idle.  `GGFE_PROFILE` was enabled in the device build.
Review found that the commit and documentation claimed lifetime CPU-governor
control, but `plumos-ggfe-launch` still used `exec` and contained no snapshot,
apply, or restore operation.  Commit `bc27cd4` adds the missing
`ondemand -> performance -> ondemand` contract and tests non-zero child exit,
apply failure, and TERM cleanup.

The complete 212-entry frontend component was rebuilt from `bc27cd4`.  Device
hashes after deployment were:

```text
f2ec0a9f13815f7cf2f4e75fd90d1fe1ce47c1ec827b0c8daf2d344ee7d378bc  bin/plumos-ggfe
09718b768aed5fd44103fbd29df05f7252a65dabc6c0deb805cc78d1ecc01880  bin/plumos-ggfe-launch
a53c78fa23db63f8d9d8d3876e3af65e652ea361ce508ecb4a8bc85a69e0584d  components/frontend/checksums.sha256
```

The component's 212 checksums and the corresponding 213 global-catalog entries
passed.  Frontend settings, system settings, and core overrides retained their
pre-deployment hashes.  The initial deployment script treated root-level
`VERSION` as a directory and stopped after switching 211 entries.  The original
component had already been captured; `VERSION`, the component checksum, and the
global entries were completed from the verified staging tree, followed by a
full component check.  A corrected rollback archive is retained under
`/storage/plumos/state/app-deploy/bc27cd4-ggfe-mt/`.

The direct validation used the frontend hold, with GGFE as the only renderer.
The expected runtime state was observed:

```text
ggfe_cpu=apply result=ok requested=performance active=performance
ggfe_renderer=ready backend=drm xres=640 yres=480 bpp=32 shadow=0 double_buffer=1
ggfe_stages=clear=528 console=0 label=715 cart3d=6265 glass=4802 console_front=0 hud=1991 flash=0 threads=4
```

The four-core renderer reduces a static compose interval to about 14.3 ms, with
blit near 2.25 ms.  This is just over the complete 16.6 ms frame deadline, so a
blocking page flip commonly pushes the next presentation to the following
vblank and the observed steady rate remains about 30 to 32 fps.  `compose_us`
alone being below 16.6 ms is therefore not a 60 fps pass.

During physical continuous D-pad scrolling, frame rate ranged from about 27 to
43 fps.  The sustained heavy intervals were normally 30 fps, with compose about
19.5 to 22.1 ms, blit about 2.2 ms, and present about 9 to 16 ms.  A
representative interval was:

```text
ggfe_frames=fps=30.00 frames=30 elapsed_ms=1000 max_frame_ms=34 slow_frames=30 compose_us=22026/22181 blit_us=2213/2226 present_us=9085/9234
ggfe_stages=clear=537 console=0 label=1489 cart3d=9624 glass=7015 console_front=0 hud=3357 flash=0 threads=4
```

The physical A path produced code 305 and launched
`gamegear/Eternal Legend (Japan).gg` through
`retroarch:genesis_plus_gx`.  The launch animation also ran at about 30 fps,
with a 19.1 ms compose average.  RetroArch exited with SELECT+START, GGFE logged
status zero, reopened its input fd, and remained controllable:

```text
ggfe_input=launch code=305 physical=A target=1
ggfe_launch=done status=0
ggfe_input=reopened-after-launch
```

Physical B then produced code 304 and exited GGFE.  No frontend or emulator was
drawing at the same time.  The wrapper restored the exact pre-launch policy:

```text
ggfe_input=exit code=304 physical=B
ggfe_exit=ok
ggfe_cpu=restore result=ok active=ondemand
```

Four workers and lifetime `performance` are accepted.  The 60 fps and motion
acceptance gates remain open.  The next optimisation should reduce the
scrolling scene's `cart3d` and `glass` work; together they account for roughly
16.6 ms of the representative 22.0 ms compose interval.

## Recovery-console power-request observation

Removing the validation hold could not restart the frontend because earlier
device work had already consumed all four restart attempts in that boot.  PID
1 entered `E81_FRONTEND_RESTART_LIMIT_RECOVERY_CONSOLE`, whose current final
action is `exec busybox sh`.  A later `plumos-safe-shutdown --reboot` correctly
quiesced the foreground, SD2, p4, network services, and recorded a PID 1
request, but no supervisor remained to consume it.  The device continued to
answer ICMP with ports 21, 22, and 445 closed until a physical power cycle.
This is a recovery-console lifecycle defect, not a GGFE or governor failure.

The following cold boot accepted the clean-shutdown markers, performed no
automatic filesystem repair, and retained `source_ref=bc27cd4`.  At 4.68
seconds the normal frontend start was dispatched.  The running state had one
frontend renderer, no GGFE/RetroArch process, `ondemand`, no validation hold,
valid 212-entry frontend checksums, unchanged mutable settings, and listening
FTP, SSH, and Samba services.

The final test used the actual `START > Apps > Game Gear` route rather than the
validation hold.  The frontend action log recorded `Apps ready` and then
`Game Gear finished`.  GGFE acquired DRM with `threads=4`, applied
`performance`, accepted sustained physical D-pad input, and physical B emitted
code 304.  After exit, exactly one normal frontend renderer was present, no
GGFE/RetroArch/broker process remained, and the policy was restored to
`ondemand`:

```text
ggfe_cpu=apply result=ok requested=performance active=performance
ggfe_input=exit code=304 physical=B
ggfe_exit=ok
ggfe_cpu=restore result=ok active=ondemand
```

The component checksum and all three mutable-setting hashes remained unchanged.
This accepts the normal Apps lifecycle and governor wrapper.  It does not close
the separate 60 fps motion gate.

## Parallel prepare and panel conversion

Commit `c4b756c` moves the background copy/depth clear and the 32-bit panel
conversion onto the existing dynamic stripe pool.  Review found that its
one-thread fallback reset `next_stripe` but still locked a mutex which had never
been initialised.  Commit `b7be9c5` makes stripe claiming genuinely lock-free
when no worker exists and adds a permanent host regression: one-thread and
four-thread builds render all six representative browse/launch PNGs
byte-for-byte identically.

The rebuilt `b7be9c5` 212-entry frontend component and its 213 corresponding
global checksum entries passed before and after the device switch.  The
transfer payload SHA-256 was
`eb43f438b0e2c2e1daedb20146d626492af52d89d013064d5b3c8aa91b6cc99a`.
Installed hashes were:

```text
c88291280e588b4e43fb836372735ba4cafc738cb2d8cbbaf637f1774e40655c  bin/plumos-ggfe
09718b768aed5fd44103fbd29df05f7252a65dabc6c0deb805cc78d1ecc01880  bin/plumos-ggfe-launch
fd9bc6d0944f39650a9cc06ca70643e0fae3fa350332d8925e4282c406c2e96d  components/frontend/checksums.sha256
```

Rollback is
`/storage/plumos/state/app-deploy/b7be9c5-ggfe-parallel-io/rollback.tar`,
SHA-256
`5467b34f0dc4b97533283ee555eb781fc6526c5a0b5a402fbe6ca22cd02821e1`.
The three mutable configuration hashes stayed unchanged.

On the physical device, the panel conversion fell from about 2.25 ms to about
0.85 ms, a roughly 62% reduction.  Parallel prepare did not help: the measured
`clear` stage increased from about 0.53 ms to about 1.02 ms because dispatch
overhead is larger than the memory operation saved.  Net frame work improved
by about 0.9 ms.

At the left library boundary, where fewer cases are visible, a stationary
frame now meets the display deadline:

```text
ggfe_frames=fps=60.00 frames=60 elapsed_ms=1000 max_frame_ms=17 slow_frames=0 compose_us=14826/14972 blit_us=851/932 present_us=983/1161
ggfe_stages=clear=1025 console=1 label=737 cart3d=6269 glass=4756 console_front=0 hud=2034 flash=0 threads=4
```

Repeated stationary intervals were 58 to 60 fps, with compose approximately
14.83 to 14.93 ms and blit approximately 0.85 to 0.87 ms.  This accepts the
static 60 Hz target at that boundary.

Continuous physical D-pad scrolling improved perceptually according to the
user, but it is not a 60 fps pass.  Depending on carousel position it measured
about 27.5 to 39 fps.  A representative centre interval remained 30 fps:

```text
ggfe_frames=fps=30.00 frames=30 elapsed_ms=1000 max_frame_ms=34 slow_frames=30 compose_us=20627/22384 blit_us=873/958 present_us=11809/13577
ggfe_stages=clear=1014 console=0 label=1265 cart3d=8958 glass=6882 console_front=0 hud=2504 flash=0 threads=4
```

Physical A launched `gamegear/Columns [V1.0].gg` through
`retroarch:genesis_plus_gx`.  The launch animation measured 47 to 60 fps.
RetroArch exited with SELECT+START, status was zero, and GGFE reopened input.
Physical B then ended GGFE through the normal Apps route.  The final state had
one frontend renderer, no GGFE/RetroArch/broker process, `ondemand`, no
validation hold, valid component checksums, and unchanged mutable settings.

The parallel blit and complete normal lifecycle are accepted.  The user's
visual assessment was that scrolling is substantially better and visibly
smooth, but centre scrolling remains below 60 fps.  Removing or changing case
rendering would alter the frontend appearance and was not done without a
separate product decision.

## Physical cartridge-case toggle

Commit `de1912e` connects physical X (`BTN_NORTH`, evdev code 307) to the
existing `ggfe_frame.cased` render branch.  Browse mode retains the selected
visibility for the current GGFE process; the launch animation still presents
the case.  Host input-contract, one/four-thread byte-identical render,
governor, and START/Apps route tests passed before deployment.

The complete 212-entry frontend component and the corresponding 213 global
catalog entries were switched together.  Installed hashes were:

```text
f8375aac3e8dae36155a484bf4c6de92b6a36f1028ee7163ad15ce1510735ce9  bin/plumos-ggfe
4409bd9e4b185247fb2a96d80155269b63f6f84e63744b123571a62f014b0dd0  components/frontend/checksums.sha256
```

Rollback is
`/storage/plumos/state/app-deploy/de1912e-ggfe-case-toggle/rollback.tar`,
SHA-256
`893fef92e4f9f677cfddcfd97b94946caad9c4bbd16979e4a9f3062ea71e0166`.
Its size is 45,483,008 bytes.  Frontend and system setting hashes were
unchanged.

The first one-off global-catalog rewrite used AWK `$2` and therefore truncated
pre-existing paths containing spaces.  A full verification exposed 5,224
unreadable entries before any reboot.  The saved pre-switch catalog was
restored and the 213 frontend hashes were reapplied using the complete path
from character 67 onward.  Final structural proof found all 12,725
non-frontend catalog lines byte-for-byte unchanged and separately verified all
213 frontend entries and all 212 component entries.  BusyBox `sha256sum -c`
cannot parse the catalog's space-containing paths, so it is not a valid full
catalog verifier on this image; the handover now records this constraint.

The user physically confirmed case OFF and ON.  GGFE logged all three toggles:

```text
ggfe_input=case-toggle code=307 visible=0
ggfe_input=case-toggle code=307 visible=1
ggfe_input=case-toggle code=307 visible=0
```

With cases enabled, continuous D-pad scrolling measured approximately 27.5 to
39.3 fps with compose averages of about 18.4 to 20.6 ms.  With cases disabled,
steady scrolling was mainly 51 to 60 fps with compose averages of about 12.6
to 14.6 ms; samples crossing the toggle were 40 to 45 fps.  Case-off stationary
frames repeatedly held 60 fps at about 13.2 ms compose.  The profile confirmed
that the glass stage fell from roughly 3.7 to 6.9 ms to effectively zero.
There was one late 30 fps case-off interval, so this does not close the global
60 fps gate.

Physical B then produced code 304, GGFE logged a clean exit, and the launcher
restored `ondemand`.  Final state was one frontend process, no GGFE or DRM
broker process, valid frontend checksums, and unchanged mutable settings.  The
X toggle and its normal Apps lifecycle are accepted.

## HUD glyph cache

Commit `9d98b66` adds a 192-entry LRU cache keyed by Unicode codepoint and pixel
size.  Review confirmed that the cache is used only by the main composition
thread, releases evicted coverage buffers, and frees every retained buffer at
shutdown.  In addition to the permanent one/four-thread comparison, all six
representative browse/launch PNGs were rendered with `9d98b66^` and
`9d98b66`; every pair was byte-for-byte identical.

The complete 212-entry component was staged and verified, but only the two
changed payload files, component metadata, and the corresponding 213 global
entries were switched.  The other 12,725 global catalog lines remained
byte-for-byte unchanged.  Installed hashes were:

```text
7a1406744f418a36aa605d8884a741f4f9e9321bbb2e9008ca9de090f79f9bdc  bin/plumos-ggfe
424ffc06d4eb4df4e16b663acadf14a60663e16bf02d9ea7195ca3a1dc5fa806  components/frontend/checksums.sha256
```

Rollback is
`/storage/plumos/state/app-deploy/9d98b66-ggfe-glyph-cache/rollback.tar`,
SHA-256
`36a3b15b7e87df65e459f9cb60ef5764add13cf0b64161bc92fdc1bec95178bc`.
Its size is 1,545,728 bytes.  Frontend and system setting hashes were
unchanged.

The physical run used `START > Apps > Game Gear`, scanned 20 ROMs, and logged
the expected DRM backend and four renderer threads.  Comparing browse frames
whose console and flash stages were inactive gave:

| Cases | Before cache HUD | Cached HUD | Reduction |
|---|---:|---:|---:|
| ON | 2.295 ms average (1.876--3.223 ms) | 1.122 ms (1.087--1.199 ms) | 51.1% |
| OFF | 1.981 ms average (1.727--3.286 ms) | 1.098 ms (1.026--1.312 ms) | 44.6% |

Case-on centre scrolling remained approximately 28 to 30 fps with compose
about 18.8 to 20.1 ms, so the cache does not close the 60 fps gate.  Case-off
scrolling was mainly 52 to 60 fps and compose was commonly 11.7 to 12.4 ms.
This is the expected roughly one millisecond device-side saving.

During the same session three physical A presses launched Game Gear content.
All three launches returned status zero and reopened GGFE input.  The launcher
did emit the pre-existing `missing safe hotkeyd` warning, but RetroArch's
SELECT+START route and GGFE return both completed.  Physical B then logged a
clean GGFE exit.  Final state had one frontend process, no GGFE or DRM broker,
`ondemand`, valid component checksums, and unchanged mutable settings.  The
glyph cache and its normal lifecycle are accepted; all-position 60 fps remains
open.

## Presentation fixes and remembered case state

Commit `baa76ed` addresses three physical presentation findings: portrait box
art margins now use the cartridge shell colour rather than a blurred dark copy
of the artwork, case visibility is stored in GGFE's own
`state/frontend/ggfe-state.json`, and a case-off launch skips the lid-opening
portion of the timeline while keeping the case hidden.  Commit `27bd746`
strengthens the state transaction by checking every write/flush/file-sync/close
result, syncing the directory after rename, and logging durability failures.

A generated portrait artwork fixture rendered both revisions side by side.
The old frame visibly carried the artwork's red-brown colour into both side
bars; the new frame used the neutral shell colour.  A separate case-off launch
frame showed no tray or lid and entered at `GGFE_LAUNCH_NO_CASE_START`.  The
permanent host test verifies default ON, saved OFF, restored OFF, saved ON, and
restored ON.  It also compares seven representative case-on/case-off frames
between one and four renderer threads byte-for-byte.

The rebuilt 212-entry component was staged and verified.  The live delta was
four managed files with no removals: the GGFE binary, managed and factory
`ggfe.json`, and component manifest.  Before updating the managed config, its
device hash was proven identical to the previous packaged default, so no user
customisation was overwritten.  All 213 frontend global entries passed and the
other 12,725 catalog lines remained byte-for-byte unchanged.  Installed hashes
were:

```text
959c2ccefdfd69a5ae03776e4db5313063f375ab584270884c8e0e1c3ff44480  bin/plumos-ggfe
58c7a923bd4a3c2d160c1b479abd8dcd3ecdb9132c89e03396c2370106ae92e7  components/frontend/checksums.sha256
c4cd46524bbad09651016ca20fb00950c41e0b3f6de1810d39136c2c0e248840  config/frontend/ggfe.json
```

Rollback is
`/storage/plumos/state/app-deploy/27bd746-ggfe-presentation-state/rollback.tar`,
SHA-256
`ce84bcafa6aaaddd59a987dfbae31921577b500967d1091a7f0b49382ceae088`.
Its size is 1,549,824 bytes.  Frontend and system setting hashes were
unchanged.

The user physically accepted all three visible behaviours.  The first Apps
launch reported `show_cases=1`, physical X wrote OFF, and the log recorded:

```text
ggfe_input=case-toggle code=307 visible=0
ggfe_state=saved show_cases=0
```

Three case-off physical A launches returned status zero and reopened GGFE
input.  After leaving and reopening GGFE, the next process reported
`ggfe_start=ok roms=20 show_cases=0`, proving device-side OFF persistence.
There were no state write, rename, or sync errors and no stale `.next` file.
The reverse OFF-to-ON persistence is covered by the host round-trip fixture;
the physical run left the preference OFF.

The final START exit returned to one frontend process with no GGFE or DRM
broker, restored `ondemand`, and retained valid component checksums.  Portrait
margin rendering, case-off launch presentation, and remembered view state are
accepted.

## Cyclic snap navigation

The user compared both selectable motion models on the device and chose the
240 ms `snap` model because its visual tempo was better.  Commit `7250b3e`
keeps that shipped default and adds navigation that does not depend on kernel
key-repeat events: left and right repeat after 350 ms and then every 95 ms,
matching the stock frontend.  Up and down make one cyclic five-entry move.

The carousel now treats the library as cyclic geometry as well as cyclic
selection.  Logical positions remain continuous across the boundary while ROM
indices are wrapped for drawing, so the final-to-first move occupies one slot
instead of interpolating across the whole library.  A completed logical turn
is collapsed back to the physical index before another move, preventing both
long-path interpolation and floating-point drift after long holds.

Host gates covered three- and twenty-entry wrapping, repeat press/delay/
interval/release, snap and gallery curves, and nine representative frames
including both boundary directions.  All nine frames were byte-identical with
one and four renderer threads.  Physical input, CPU-control and START-menu
contracts also passed.

The 212-entry frontend component was deployed with source `7250b3e`.  Its live
delta from the temporary gallery comparison state was three managed files:
the GGFE binary, active `ggfe.json`, and component manifest.  Component and
global metadata were switched with them; all 212 component entries and all 213
frontend global entries passed while the other 12,725 global catalog lines
remained byte-for-byte unchanged.  Installed hashes were:

```text
766b485562b930600ed45d6e788f5f45ee326c44fb4034b1b760bd0d9ff65384  bin/plumos-ggfe
b5a1c6e7854edb8f57e584fc5e7e83b0bae819d81400b26279348f6b3b85e6c9  config/frontend/ggfe.json
87d3bfbcf53247b1179bde7e902fb6465757d546cd86500024b6e367576e3f81  components/frontend/checksums.sha256
```

Rollback is
`/storage/plumos/state/app-deploy/7250b3e-ggfe-cyclic-navigation/rollback.tar`,
SHA-256
`b52c2c3e6a9ecf511fb4c553657245e0b58da5c8a1c509bebbdfcc2ee228a061`.
It is 1,548,288 bytes and includes the prior gallery comparison setting.

The physical library contained 20 ROMs.  Fractional re-aim origins during a
held direction proved that GGFE's own repeat fired before the preceding snap
settled.  The two exact boundary routes were recorded as:

```text
ggfe_scroll=start from=0.000 to=-1 selected=19 delta=-1 duration_ms=240 model=snap
ggfe_scroll=start from=19.000 to=20 selected=0 delta=1 duration_ms=240 model=snap
```

Both five-entry directions and their wrap were also observed, including
`from=19.000 to=24 selected=4 delta=5` and
`from=4.000 to=-1 selected=19 delta=-5`.  Six selected games launched with
status zero and GGFE reopened input after every return.  The user accepted the
held repeat, both one-entry boundary routes, and both five-entry moves by eye.

Seamless cyclic geometry means the former cheap endpoint no longer omits the
opposite-end neighbours.  With cases on, the accepted visual run therefore
remained around 27--30 fps with compose commonly 19--20 ms even at a library
boundary; this does not close the all-position 60 fps gate.  It is an expected
cost of the requested continuous carousel rather than a motion-curve cost.

Physical B returned to one stock frontend process.  No GGFE, DRM broker or
emulator remained, the governor returned to `ondemand`, GGFE's state and the
other mutable setting hashes were retained, and the component/global
checksums passed again after acceptance.
