# Bubble transfer-service write validation

Date: 2026-09-05

Device: GKD Bubble at `192.168.10.101`

Source: `973edcf`

## Cause

BusyBox FTP was already started as UID 0 with upload support, and both
`/storage` and `/storage/user` accepted directory creation. Only `Roms` and
`BIOS` failed with FTP status 550 because `/dev/mmcblk3p1` and its two bind
mounts were explicitly mounted read-only. This was a mount-policy failure, not
an FTP authentication or Unix mode failure.

## Change

`plumos-bubble-mount-sd2` now follows the V90S removable-content contract:

- default vfat access is
  `rw,utf8,shortname=mixed,fmask=0022,dmask=0022,errors=remount-ro`;
- existing Roms and BIOS bind mounts are remounted to the same access state as
  the SD2 parent mount;
- an initial read-write mount failure falls back to read-only content instead
  of hiding the library;
- `PLUMOS_SD2_ACCESS=ro` remains available for explicit maintenance use;
- no automatic filesystem repair or boot-time scan was added.

The live mount and both bind mounts reported `rw` after deployment. Kernel
`errors=remount-ro` remains the runtime protection if FAT errors occur.

## Protocol acceptance

The following public roots were tested independently over FTP, SFTP, and the
Samba `SDCARD` share:

`Roms`, `BIOS`, `Images`, `Manuals`, `Music`, `Patches`, `Screenshots`,
`Shaders`, `Themes`, `exports`, `imports`, and `updates`.

For every protocol and every root, the test created a unique directory,
uploaded a file, read it back, compared SHA-256, removed the file, and removed
the directory. Results were:

- FTP: 12/12 passed;
- SFTP subsystem on port 22: 12/12 passed;
- Samba `SDCARD`: 12/12 passed.

All probes were removed. No ROM, BIOS, save, configuration, or other existing
user content was modified or deleted.

## Post-deployment state

- FTP, SFTP, and Samba reported `running`;
- frontend count was one;
- no transfer-probe directories remained;
- no new FAT corruption or mmcblk3 I/O error appeared in the kernel log;
- all ten component checksum manifests passed;
- the live app-layer checksum was regenerated from those validated component
  versions and passed with 12,890 managed entries;
- rollback data is retained under
  `/storage/plumos/.rollback/bubble-ftp-write-973edcf`.
