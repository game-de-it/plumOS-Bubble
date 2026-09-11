# BIOS, saves, states and screenshots

Put BIOS files you are legally entitled to use in `BIOS/`. SD2's root `BIOS/`
is active when SD2 is present; otherwise SD1's `BIOS/` is used.

Disc systems such as Sega CD, Saturn, PlayStation, PC Engine CD, Neo Geo CD and
PC-FX, plus some computer and arcade systems, require the correct BIOS or ROM
set. A recognized extension does not imply BIOS-free or universal compatibility.

| Data | Device path |
| --- | --- |
| RetroArch saves | `/storage/plumos/saves/` |
| RetroArch save states | `/storage/plumos/states/` |
| Screenshots | `/storage/Images/` (`Images/` on the FAT32 volume) |
| Settings | `/storage/plumos/config/` |
| Logs | `/storage/plumos/logs/` |

Standalone emulators and ports may use runtime-specific locations. Saves,
states, settings and logs live on the device-managed partition, not the FAT32
volume shown when SYS is inserted in a computer. Back them up over SFTP or
Samba. Updates are designed to preserve them.

The factory Game Gear shader is
`/storage/plumos/config/shaders/gamegear-lcd.glslp`.
The B3 profile models the SEGA STN panel's colour, non-square pixels, vertical
RGB structure, horizontal CCFL and asymmetric response. Back it up before edits.
