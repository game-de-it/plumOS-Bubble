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
- Network now has AP6330/wpa_supplicant control and Dropbear SSH control.
- Lid suspend, display color/lumination, PicoArch reset, FTP,
  SFTP, Samba and ADB remain visible as unsupported until a real Bubble backend
  exists.
- System Update follows the current MF manual-SD update contract while the
  Bubble A/B system-slot updater remains tracked under `BUB-P3-03`/`P3-05`.
- Scraping, Thumbnail Plan and Fetch Thumbnails use the common policy-aware
  scraper with Bubble's 98-system catalog and SD2 media roots.
- File Manager is a Bubble build of NextCommander with the recorded physical
  A/B and D-pad button numbers, 640x480 DRM output and mutable state isolation.
- Music Player uses Bubble DRM, the managed ALSA route, physical-label input,
  Japanese fonts and both primary/SD2 music roots.

The machine-readable contract is
`config/frontend/start-menu-coverage.json`. It records order, implementation
state, unsupported reason/TODO, and empty Bubble-only arrays.

## Host verification

- Shell syntax checks: passed.
- START/Apps JSON order and Bubble-only assertion: passed.
- Factory reset and safe-power dry-run fixtures: passed.
- AArch64 frontend build and component checksums: passed.
- Text renderer: START reports 8 entries and Apps reports 10 implemented entries.

Physical LCD navigation and device-helper behavior remain a separate device
acceptance step. No release or publication is authorized by this audit.
