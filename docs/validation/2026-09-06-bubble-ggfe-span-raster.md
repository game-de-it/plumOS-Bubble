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
RetroArch SELECT+START exit chord remained queued on the evdev fd that GGFE had
kept open during the child process.  Immediately after `ggfe_launch=done`, two
`ggfe_input=exit code=315 physical=START` records caused an unintended GGFE
exit.  This is not a valid physical START acceptance result.  The input fd must
be closed before the emulator launch and reopened after return, then the return
route must be retested.

The validation hold was removed and the normal frontend returned after three
seconds.  Final state was exactly one
`plumos-controller-ui-fbdev`, no GGFE or RetroArch process, no validation hold,
valid frontend component checksums, and unchanged mutable configuration.

The physical appearance of the improved motion has not been accepted, and the
60 fps and post-game input-isolation gates remain open.
