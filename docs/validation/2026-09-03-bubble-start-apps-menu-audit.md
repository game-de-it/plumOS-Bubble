# Bubble START / Apps menu audit

Date: 2026-09-03

## Result

Bubble-specific additions are zero in both START and Apps. The Apps catalog is
an exact id/order match for plumOS-MF and plumOS-V90S v2. Bubble had one common
START omission: Performance Settings. It has been restored between Network
Settings and Apps.

The resulting START order is:

1. UI Settings
2. System Settings
3. Network Settings
4. Performance Settings
5. Apps
6. Help
7. Reboot
8. Shutdown

The Apps order is Scraping, File Manager, Music Player, RetroArch, Pyxel Setup,
PortMaster, Update PortMaster, Thumbnail Plan, Fetch Thumbnails, and Thumbnail
Results. A30 lacks the newer Pyxel/PortMaster entries, MMF has its hardware-only
PWM test, and XU20 adds three no-content cores; none of those device-specific
differences were copied into Bubble.

## Implementation status

- UI, Help and all menu navigation are handled by the common frontend.
- Performance is connected to `plumos-cpu-control`.
- System now has Bubble backlight, time/RTC, factory reset, storage, volume and
  safe power helpers.
- Network now has AP6330/wpa_supplicant control, shell SSH on port 22, BusyBox
  FTP on port 21, a dedicated Dropbear/OpenSSH SFTP route on port 2222, and an
  authenticated Samba `SDCARD` share on port 445.
- Display lumination and display color use the Bubble Rockchip DSI connector's
  native 0..100 `brightness`, `contrast`, `hue`, and `saturation` DRM
  properties. The frontend owns the DRM master and applies values through that
  exact fd, including startup restoration.
- PicoArch reset now restores a packaged Bubble default environment rather than
  showing a placeholder.
- System Update scans `/storage/user/updates` for the newest compatible signed
  Bubble Runtime package, verifies its Ed25519 signature and ABI/vendor/source
  constraints, records the request, and reboots through the normal safe-power
  helper. Early frontend startup applies managed files with a per-path journal
  and rollback copy; the transaction is accepted only after the DRM frontend
  writes its renderer-ready proof. A subsequent boot before that proof restores
  the previous Runtime. Active settings, saves, states, logs, ROMs, BIOS,
  credentials and installed PortMaster state are outside its managed inventory.
- Lid suspend remains visible but hardware-blocked: the runtime DT, input
  inventory and interrupt inventory expose no lid/hall sensor. USB ADB remains
  visible but hardware/kernel-blocked: the stock kernel config builds the DWC3
  gadget stack as modules, but the image contains none of those modules and
  therefore exposes no UDC. Neither item is reported as working.
- Boot/kernel/DTB/System replacement remains a full-image operation until the
  matching-set and A/B slot work tracked under `BUB-P3-03`/`P3-05` is complete;
  the functional START route deliberately accepts Runtime packages only.
- Scraping, Thumbnail Plan and Fetch Thumbnails use the common policy-aware
  scraper with Bubble's 98-system catalog and SD2 media roots.
- File Manager is a Bubble build of NextCommander with the recorded physical
  A/B and D-pad button numbers, 640x480 DRM output and mutable state isolation.
- Music Player uses Bubble DRM, the managed ALSA route, physical-label input,
  Japanese fonts and both primary/SD2 music roots.

The machine-readable contract is
`config/frontend/start-menu-coverage.json`. It records order, implementation
state, hardware-blocked reason/TODO, and empty Bubble-only arrays.

## Host verification

- Shell syntax checks: passed.
- Signed Runtime update fixture: Ed25519 verification, two transactional applies,
  frontend health confirmation, two boot-before-health rollbacks, managed file
  deletion, and active-setting preservation passed.
- START/Apps JSON order and Bubble-only assertion: passed.
- Factory reset and safe-power dry-run fixtures: passed.
- AArch64 frontend build and component checksums: passed.
- Text renderer: START reports 8 entries and Apps reports 10 implemented entries.
- Bubble DRM probe: active DSI connector has all four 0..100 properties.
- New frontend device test: 40/60/70/80 was applied and read back for
  brightness/contrast/hue/saturation, then restored to 50/50/50/50.
- FTP device/client test: port 21 started, the isolated validation file was read
  back with `curl`, and the service stopped cleanly.
- SFTP device/client test: port 2222 started, password authentication succeeded,
  the same file was read back with the macOS SFTP client, and the service stopped.
- Samba device/client test: port 445 started, macOS mounted `SDCARD`, read back
  the isolated file with the same SHA-256, unmounted, and the service stopped.
- The integrated Runtime was deployed as source `bdb7916`. All 12,373 managed
  app-layer files passed device-side SHA-256 verification. Existing frontend
  settings, system settings and the Dropbear host key retained their exact
  pre-deployment hashes; a 35 MB rollback snapshot remains on-device.
- The final, normal `/storage/plumos` service path was retested after deployment:
  FTP, SFTP and Samba each returned the same probe bytes to the macOS client and
  were then disabled. This also verifies the SFTP forced-command fallback after
  Dropbear removes its inherited environment.
- A signed 71-byte Runtime fixture was transferred to the normal p4 inbox and
  passed `inspect` and `scan` using the bundled AArch64 Python and OpenSSL. It
  was not requested or applied, and was removed after the check.
- The frontend returned as exactly one process, wrote renderer-ready proof, and
  held `/dev/dri/card0`, `event0`, and `event2`. The live DSI property readback
  was brightness/contrast/hue/saturation = 50/50/50/50.
- File Manager and Music Player remained alive with DRM/input ownership; Music
  Player also held the expected PCM fds. Both were terminated by the bounded
  validation harness rather than crashing.

Physical LCD navigation, PortMaster GUI, reboot/shutdown media cleanliness, and
the two hardware-blocked routes remain separate acceptance items. No release or
publication is authorized by this audit.
