# Bubble save-state and reboot physical acceptance

Date: 2026-09-10 (device UTC log date 2026-09-09)

## Scope

This closes `BUB-P5-06` without generalizing one NES route to the remaining
runtime matrix. The normal frontend launch path was used throughout; the
frontend released the display before RetroArch and reacquired it after exit.

## Physical sequence and evidence

- Launched `Akumajou Densetsu.nes` through `retroarch:quicknes`.
- Opened the RetroArch menu with physical Function1 and saved a manual state.
- The device wrote a 12,864-byte state plus its PNG thumbnail and an automatic
  exit state.
- Loaded the manual state in the same boot; the user confirmed the exact saved
  scene and returned with SELECT+START. RetroArch exited with `rc=0` and the
  frontend became the sole DRM owner.
- Reboot changed the boot ID from
  `2584ec9d-50e7-4db1-b9dc-59a11cca2d2f` to
  `4a7ae397-3686-434b-8d7a-475dc3364d21`.
- The manual state hash remained
  `a0b4cc509ec62c29368598f32660a5bdfa7347ab134687e0c17dbab944015820`.
- After reboot the user loaded it again, confirmed the saved scene, exited, and
  returned to the frontend.

## Separate power finding

The same reboot exposed an independent power-finalization regression:
`user-unmount result=ok clean-markers=written` was followed by
`E91_STORAGE_READ_ONLY_FAILED` and the next boot reported
`previous_shutdown=unknown`. Save-state persistence passed, but this is not
accepted as clean-filesystem proof. The fix moves Dropbear's inherited log FD
to tmpfs, terminates only residual `/storage` writers without a fixed delay,
and refuses the terminal backend if the read-only remount still fails.

