# Writing the system card and first boot

## Requirements

- A GKD Bubble
- A 16 GB or larger microSD card for SYS
- The compressed release image and `SHA256SUMS`
- A raw-image writer such as Raspberry Pi Imager or balenaEtcher

## Procedure

1. Download the image and `SHA256SUMS` from the same release.
2. Verify the SHA-256 digest.
3. Write the card as a **raw disk image**, not as a copied file.
4. Let the writer verify it, then safely eject the card.
5. With the Bubble powered off, insert it into the **top-edge SYS slot**.
6. Power on and wait until first-boot setup finishes and the frontend appears.

First boot expands partitions and creates the writable user area. Do not power
off or remove the card while this is in progress.

## Optional SD2

Format a ROM card as FAT32 and create `Roms` and, when needed, `BIOS` at its
root. Insert it into the **bottom-edge SD2 slot** while powered off. See
[Using SD1 and SD2](storage.md).

## Caution

Choosing the wrong target in an image writer can erase another computer drive.
Check the device name and capacity before writing. Writing a raw system image is
different from copying an update package to a card.
