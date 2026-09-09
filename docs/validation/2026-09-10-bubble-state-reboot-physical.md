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

## Fast fail-safe power follow-up

Source `b292210` was rebuilt and deployed as a scoped managed update. The live
device's checksum lists were used as the baseline, so unrelated newer build
outputs such as RetroArch, BusyBox and Game Gear shader defaults were not
installed. The frontend 217-entry checksum, network-services checksum and the
complete app-layer checksum all passed after the atomic switch. Mutable config
hashes were identical before and after deployment. The retained rollback is:

```text
/storage/plumos/state/app-deploy/b292210-power-fast-20260910T021301/rollback.tar
SHA-256 8cb25ebc387c4623d4fd75ececf85788bcaf5accb7426d088c509b8f1f077619
```

The rebuilt System was written to inactive slot B and read back as
`d733f035899a78bb564a63f51caa98ad93016eedb7d957a985f9e4b70960732a`.
Slot A remains the byte-verified rollback at
`bf08369a3fa8af91ccd20a463f42d217e4944d7a8cde8d92ec7a611148641db7`.

The user then exercised both normal frontend actions:

- Reboot began at `17:55:46Z`, reached the terminal stage at `17:55:47Z`, and
  requested the backend at `17:55:48Z`.
- Shutdown began at `17:59:19Z`, reached the terminal stage at `17:59:20Z`,
  and requested the backend at `17:59:21Z`. The user observed actual power-off
  in approximately four seconds.
- Both following boots reported `previous_shutdown=clean automatic_repair=no`.
- The shutdown boot reached frontend start at kernel timestamp 3.89 seconds.
- Active slot B and its System checksum passed after both boots. The frontend
  was the only renderer after return.
- Dropbear held no descriptor below `/storage`; its persistent stdout/stderr
  descriptors resolved to `/run/plumos/dropbear/dropbear.log`.

There is no new fixed power delay. A clean idle system proceeds immediately;
only an actual residual `/storage` writer receives the bounded termination
path. The existing offline FAT dirty-flag inspection remains a separate open
part of `BUB-P4-P04`.

## Charger transition and battery reboot

The charger was removed while the frontend was idle. The device changed to
`bq2589x-usb online=0`, battery `Discharging`, and logged `adapter removed`.
The frontend and Wi-Fi remained available with no second renderer. A normal FE
reboot while still disconnected again reached the backend request in two
seconds. The following boot reported `previous_shutdown=clean`, retained
System B, remained in battery discharge state, and started the frontend at
kernel timestamp 3.84 seconds.

The charger was then reconnected while the frontend remained active. The
device changed to `bq2589x-usb online=1`, battery `Charging` at approximately
1.03 A, and logged `usb dcp adapter plugged in`. The frontend and Wi-Fi stayed
available. Charger disconnect, battery-only reboot, and live reconnect are
therefore accepted. Actual suspend/resume remains the only open power-mode
portion of `BUB-P4-P03`.
