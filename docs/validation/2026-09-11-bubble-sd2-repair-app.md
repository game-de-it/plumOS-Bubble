# Bubble SD2 repair App

Date: 2026-09-11

## Scope

Bubble exposes an explicit `Repair SD2` entry under START > Apps. This is the
handheld equivalent of a quick Windows ScanDisk pass for the removable FAT32
ROM card. It does not run during boot and it never targets the OS SD.

The first A press displays a confirmation message. A second A press within five
seconds starts the repair. The frontend remains the display owner and shows
`Repairing SD2; do not remove the card or power off` for the complete blocking
operation, so a black or apparently hung screen is not presented to the user.

## Safety contract

`plumos-sd2-repair` accepts only the mounted `/run/media/sd2` FAT filesystem.
It rejects the device when it resolves to the `/storage` disk, when the media is
not FAT, or when the exact SD2 cannot be unmounted. The operation is:

1. release the SD2 ROM and BIOS bind mounts;
2. synchronize and unmount the SD2 filesystem;
3. run the packaged dosfstools `fsck.fat -a` with a 120 second bound;
4. restore the content mounts read-write after success;
5. restore them read-only after timeout or an uncorrected error;
6. atomically update the per-media storage-health result and retain the checker
   transcript in `state/storage-health/fsck-repair.log`.

An interrupted frontend process has an EXIT/signal cleanup path that attempts a
read-only remount. Existing boot-time behavior remains observation-only: this
feature does not reintroduce automatic startup repair.

The dosfstools executable, loader, libc, required gconv module, and Debian
dosfstools/glibc copyright records are a self-contained `storage-tools` runtime
in the frontend component. This avoids depending on the older StockOS
userspace ABI.

## Host validation

`tests/test-bubble-storage-health.sh` fixes the following behavior:

- passive observation and read-only checking never repair;
- explicit repair unmounts before passing `-a` to the checker;
- successful repair restores read-write access;
- an uncorrected checker result returns non-zero and restores read-only access;
- the OS storage disk and a busy/unmountable SD2 are refused.

`tests/test-bubble-start-menu-contract.sh` fixes the Apps order, Bubble-only
coverage, confirmation flag, internal action, and visible in-progress message.

## Device confirmation visibility follow-up

The first device attempt exposed a presentation fault before the checker ran:
the Apps list consumed every available text row, while the confirmation status
was appended after the list. The fbdev renderer therefore clipped `Press A
again` below the physical screen and made the first A press appear inert.

While confirmation is pending, START/Apps now reserves the fixed footer area,
reduces the visible list window accordingly, and renders both the action and
five-second confirmation window there. This keeps the destructive FAT write
behind two A presses without relying on off-screen status text.

The second device attempt reached the helper but exposed an argument wiring
fault. The frontend's general `PLUMOS_SDCARD_ROOT` is `/storage`; forwarding it
to the narrowly scoped repair helper correctly triggered its `not-sd2` refusal.
The internal action now passes the fixed Bubble SD2 mount
`/run/media/sd2`. Running and final results retain the reserved footer so both
safe refusal and successful completion remain visible.

The first successful repair returned `check_rc=1`, cleared the dirty bit, and
restored all SD2 mounts read-write. It also exposed a codepage mismatch:
dosfstools defaulted to CP850 while Bubble mounts this card with CP936, so three
valid Japanese ROM short names were classified as invalid and renamed to
`FSCK0000.*`. Their contents matched the source ROM set byte-for-byte and were
restored as `ソニックドリフト.gg`, `ソニックドリフト２.gg`, and
`ソロモンの鍵.nes`; no `FSCK*` files remain.

The repair helper now extracts `codepage=` from the active SD2 mount and passes
it through `fsck.fat -c`. The private runtime includes glibc's GBK/CP936 gconv
module and uses the built-in `C.UTF-8` locale, preventing a CP850 interpretation
from corrupting DBCS short names on later repairs.

Physical acceptance remains the Apps launch on the current dirty SD2, followed
by a clean status, rw remount, unchanged filesystem identity, ROM visibility,
and a normal reboot.
