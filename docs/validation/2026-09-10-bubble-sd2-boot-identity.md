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

The physical reinsertion then exposed the inverse case: the returned SD2 was
correctly resolved by UUID and bound read-write, but its sticky dirty status
preserved the index generated while SD2 was absent. Library indexes are now
owned and cached by media identity. A dirty medium may preserve only an active
or cached index with the same UUID/device key; otherwise one bounded read-only
library scan creates its first matching cache. Switching between SD1 fallback
and SD2 can no longer display the other medium's library.

## Physical acceptance

Completed on the physical Bubble:

1. deployed the resolver and recorded ROM SD filesystem UUID `130C-1033`;
2. performed a normal shutdown and removed only the ROM SD while power was off;
3. cold booted without SD2;
4. observed ext4 `/storage` health independently from the removed FAT card and
   completed a fresh frontend scan with zero ROM files;
5. with `show_empty_systems=false`, the user confirmed that only the expected
   built-in Pyxel system remained visible.

The same ROM SD was then reinserted while powered off and cold booted. Device
evidence after boot was:

- `resolved_by=filesystem-uuid`, UUID `130C-1033`;
- `/dev/mmcblk3p1` mounted read-write at `/run/media/sd2`;
- ROM and BIOS targets both bound read-write from `/dev/mmcblk3p1`;
- active library owner `uuid-130C-1033` with a matching cached index;
- 4,814 files under the ROM tree, 911 matched ROMs in the boot scan and 64
  non-empty frontend systems;
- the user confirmed that the SD2-backed systems were visible again.

The frontend component passed 218-file verification and the complete app layer
passed 12,461-file verification after deployment. Frontend/system settings and
the SD2 identity file retained their pre-deployment hashes.

The existing FAT dirty evidence remains recorded and no repair was attempted;
that safety policy is independent of the completed identity and visibility
acceptance.

No card is removed while the OS is running.
