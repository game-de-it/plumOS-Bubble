# Using SD1 and SD2

## SD1 in the top-edge SYS slot

This is the boot card. It contains device-managed system storage and a separate
computer-visible FAT32 volume named `PLUMOS`. The main folders to use directly
from a computer are:

- `Roms/`: ROMs and game launch files
- `BIOS/`: user-supplied BIOS files
- `Images/`: screenshots and images
- `updates/`: system update packages

The device-managed area also contains `/storage/plumos/saves`, `states`,
`config` and `logs`. They can be backed up over SFTP or Samba, but do not edit
managed system files or manifests casually. This is a different partition from
the `PLUMOS` volume shown when the SYS card is inserted in a computer.

## SD2 in the bottom-edge SD2 slot

SD2 is an optional FAT32 card. The system recognizes `Roms` (`roms` / `ROMS`)
and `BIOS` (`bios` / `Bios`) at its root. When present, SD2 supplies the active
ROM and BIOS areas. Settings, saves, states, images and logs remain on SD1.

With no SD2, SD1 still supports scanning, scraping, thumbnails and game launch.

## Safe handling

- Insert or remove SD2 only while powered off; hot-plugging is unsupported.
- Do not remove SYS until shutdown completes and both display and LED are off.
- Avoid duplicate ROM directories that differ only in letter case.
- For a suspect FAT32 SD2, use `START` → `Apps` → `Repair SD2`. Confirm the
  prompt and press `A` again within five seconds. Never power off or remove the
  card during repair. The SYS card is never the target.
