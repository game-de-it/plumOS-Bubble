# Bubble START / Apps menu audit

Date: 2026-09-03

## Result

Bubble-specific visible additions are zero in both START and Apps. The visible
Apps menu is an exact id/order match for plumOS-MF and plumOS-V90S v2. Bubble
had one common START omission: Performance Settings. It has been restored
between Network Settings and Apps.

The resulting START order is:

1. UI Settings
2. System Settings
3. Network Settings
4. Performance Settings
5. Apps
6. Help
7. Reboot
8. Shutdown

The visible Apps order is Scraping, File Manager, Music Player, RetroArch,
Pyxel Setup, PortMaster, and Update PortMaster. Thumbnail Plan, Fetch
Thumbnails, and Thumbnail Results remain implemented catalog routes but are
hidden, as they are in every checked plumOS release. A30 lacks the newer
Pyxel/PortMaster entries, MMF has its hardware-only PWM test, and XU20 adds
three no-content cores; none of those device-specific differences were copied
into Bubble.

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
- Scraping uses the common policy-aware scraper with Bubble's 98-system catalog
  and SD2 media roots. Its lower-level Thumbnail Plan, Fetch and Results routes
  stay packaged and testable but are not separate end-user Apps entries.
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
- START/visible-Apps JSON order, hidden catalog retention and Bubble-only
  assertion: passed.
- Factory reset and safe-power dry-run fixtures: passed.
- AArch64 frontend build and component checksums: passed.
- Text renderer: START reports 8 entries and Apps reports 7 visible implemented
  entries.
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

## Network information status correction

Source `6a72940` corrects the Network Information status path. The Bubble
launcher now exports `/bin/busybox`, and the frontend has the same absolute
fallback when neither the SD update BusyBox nor an app-layer BusyBox exists.
Status and the NW Service toggle are derived from the live process state rather
than the saved auto-start flag.

The post-deployment Japanese text-renderer readback was SSH=`スタート`,
FTP/SFTP/Samba=`ストップ`, and ADB=`利用不可`; no `Status Error` remained.
Starting FTP changed its information value to `スタート`, and stopping it
returned the helper state to `stopped`. The original disabled service policy was
then restored byte-for-byte. The complete 12,373-file app-layer checksum passed,
the 158-file frontend component checksum passed, and the pre-deployment hashes
of `services.conf`, system settings, and frontend settings were unchanged. The
normal frontend returned as one renderer-ready process with
`PLUMOS_BUSYBOX=/bin/busybox`; volume remained 0. A scoped rollback snapshot and
the verified deployment archive remain under
`/storage/plumos/backups/deploy-bdb7916-before-6a72940`.

Physical LCD navigation, PortMaster GUI, reboot/shutdown media cleanliness, and
the two hardware-blocked routes remain separate acceptance items. No release or
publication is authorized by this audit.

## Apps visibility audit correction

The first audit compared every `menu=apps` catalog id without checking its
`visible` flag. That incorrectly described the three thumbnail maintenance
routes as normal Apps entries and allowed Bubble's visibility drift to pass the
contract test.

Current sources for A30, MF, MMF, V90S v2, XU20 and Pixel2 all retain Thumbnail
Plan, Fetch Thumbnails and Thumbnail Results with `visible=false`. Across the
39 tagged releases whose Apps catalog was available, no tag exposed any of the
three. A direct 640x480 capture of the running MF Apps screen showed only the
seven common entries; its PNG SHA-256 was
`c89e613894cd6451730dda642af4238ef36a1675759264f1bd7fc3ecc5bbcc27`.

Bubble source `3b0d5bd` copied the MF catalog ids but changed these three entries
to `visible=true`. It also made the obsolete Apps-catalog `settings` and
`network` start entries visible, although the current frontend does not load
those legacy entries. All five flags are now restored to `false`; none of their
implementations was deleted. The contract separately checks visible Apps order,
full catalog order, hidden thumbnail order and hidden legacy order.

A cross-series hardcoded-settings id audit found no Bubble-only settings row.
Every Bubble START item is visible in at least one other plumOS series, so the
working Performance route and the eight-entry common START contract remain.

Source `a887dda` was deployed as a six-managed-file delta. The device-side
frontend component verified all 158 files and the complete app layer verified
all 12,373 files. The Bubble text renderer then showed exactly Scraping, File
Manager, Music Player, RetroArch, Pyxel Setup, PortMaster and Update PortMaster;
none of the three hidden thumbnail labels appeared. The current system,
frontend and network-service settings retained their pre-deployment SHA-256
values. The normal frontend returned renderer-ready as exactly one process and
volume remained 0. The scoped rollback and verified deployment archive are at
`/storage/plumos/backups/deploy-6a72940-before-a887dda`.
