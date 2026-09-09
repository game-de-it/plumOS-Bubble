# Bubble SD2 boot-time identity

Date: 2026-09-10

## Product boundary

The Bubble does not need runtime SD2 hotplug. The user changes the ROM card
only while the device is fully powered off. The supported contract is therefore
boot-time discovery, safe fallback when absent, and recovery on a later cold
boot after the same card is reinserted.

## Resolver contract

`plumos-bubble-mount-sd2` resolves the ROM partition in this order:

1. an explicit maintenance device override;
2. an explicit or previously recorded filesystem UUID;
3. an explicit or previously recorded filesystem label;
4. the Bubble secondary-controller partition as a first-use fallback.

After a successful mount it records the FAT filesystem UUID atomically in the
mutable user configuration. A candidate equal to `/storage`, or on the same
parent disk as `/storage`, is rejected. A missing or rejected ROM card leaves
the stable SD1 `Roms` and `BIOS` paths in place.

The host fixture proves first-use UUID recording, a later start with a changed
device selector resolved by UUID, same-OS-disk rejection, read-write bind
parity, read-only fallback, clean unbind and SD1 fallback.

## SD2-absent scan regression

The first physical boot without SD2 exposed a separate state-ownership fault.
The user correctly saved `show_empty_systems=false`, but the frontend still
displayed every system. The old index reported SD2 ROM counts (for example NES
118) even though `/storage/user/Roms` contained no files.

The frontend had skipped its scan because the single storage-health status file
carried an earlier SD2 FAT `dirty` result into the current ext4 `/storage`
fallback. Storage-health state is now isolated by device. A sticky FAT result
applies only to the same device, mount path and filesystem; it cannot suppress
an ext4 fallback scan. Reinserting the original card restores that card's own
health history.

## Physical acceptance remaining

Completed on the physical Bubble:

1. deployed the resolver and recorded ROM SD filesystem UUID `130C-1033`;
2. performed a normal shutdown and removed only the ROM SD while power was off;
3. cold booted without SD2;
4. observed ext4 `/storage` health independently from the removed FAT card and
   completed a fresh frontend scan with zero ROM files;
5. with `show_empty_systems=false`, the user confirmed that only the expected
   built-in Pyxel system remained visible.

Remaining:

1. perform a normal shutdown, reinsert the same ROM SD while powered off and
   cold boot;
2. verify UUID resolution, ROM/BIOS binds and frontend library visibility.

No card is removed while the OS is running.
