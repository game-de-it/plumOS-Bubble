# Bubble release-candidate final device check

Date: 2026-09-11

## Starting point

The user booted the `0.1.0-rc1` release SD, connected Wi-Fi and launched the
Clang YabaSanshiro build through the normal frontend route. `Virtual Hydlide`
displayed correctly and exited with `yabasanshiro_exit=rc-0`.

The card initially contained source `9c97b28`. System slots A and B both read
back as:

```text
ca8900baccb7abfac8fdc2a9d371e5160a5f0557df2055116ca87c0479619a2d
```

The factory Game Gear `SEGA-HCCFL-B3` preset read back as:

```text
e5396c1e6b74dd3b4dc5be618285e9868b291bfddb7d9c7febba73f6d6cc4635
```

## Faults found and corrected

The SSH/recovery reboot route exposed a race that the normal frontend power
menu had not triggered. Its eight-second delayed finalizer could win while a
restarted frontend still held `/storage` log descriptors. The read-only
remount was then refused and p4 was left unmounted. Source `d23d35e` makes the
fallback repeat PID 1's storage-writer quiesce and restores p4 when a terminal
action is refused. The same route then changed boot ID successfully and p4 was
mounted read-write after boot.

That test also exposed the Bubble vendor kernel's FAT behavior: a direct SD2
rw unmount leaves the FAT dirty bit set. A rw-to-ro transition before unmount
produced a clean `fsck.fat -n` result. Source `f29dba3` adds that transition.
During the finalizer wait, frontend supervision can mount SD2 again, so source
`0a3a3b6` also repeats SD2 stop after terminating late storage users.

The final reboot from `0a3a3b6` recorded both SD2 stops, changed boot ID to
`de519e8b-e99d-430c-a4da-b5ee20fe1156`, and produced no FAT, ext4 or I/O error
in the new kernel log. The explicit SD2 checker then returned `check_rc=0`,
`result=clean`, with the filesystem restored read-write.

An intermediate device-side global checksum rewrite incorrectly used the
second whitespace field and truncated 5,224 paths containing spaces. No
managed payload was changed by that error. The original checksum file was
recovered from the pre-deploy rollback archive, regenerated with the complete
path starting at byte 67 and switched atomically. All later checks use the
path-safe parser.

## Final device state

- OS: `0.1.0-rc1`, app-layer source `0a3a3b6`
- managed checksums: frontend 227/227 and global 12,477/12,477 pass
- storage: p1 read-only; p3, p4 and SD2 read-write; SD2 ROM/BIOS binds present
- network: Wi-Fi `192.168.10.101`; SSH, FTP and SMB listeners present
- display ownership: one `plumos-controller-ui-fbdev`; no emulator remains
- library scan: 97 catalog systems, 4,011 files seen, 922 matched, 926 ROMs,
  completed in 2,276 ms
- capacity: p3 5.6 GiB free, p4 21.2 GiB free, SD2 53.4 GiB free
- YabaSanshiro binary contains the expected Clang 14 compiler identity

Retained rollback archives:

```text
496c5305f18fdba41f7ec763c9a21d099fc9ee34caa0a7e11636690cc4f01396  d23d35e-power-finalizer-20260911/rollback.tar
51669f92393b7782b15fd136dafccca5dc3acd6eaa4f232d15a95edf30cec4e0  f29dba3-sd2-clean-unmount-20260911/rollback.tar
aa63a4f37790dce6cf59198e3a745d0550843bf68a37a9011cb020dd4856386c  0a3a3b6-late-sd2-quiesce-20260911/rollback.tar
```

## Rebuilt image

The final image was assembled from the exact app-layer extracted from the
physically tested `9c97b28` image, overlaid only with the two physically
validated scripts and their device-read-back metadata. This avoids pulling in
unrelated, rebuilt core binaries from host caches.

```text
file=plumOS-Bubble-0.1.0-rc1-full-stack-validation.img
source_ref=0a3a3b6
image_size=3036676096
image_sha256=be49fdc3f0ec9f5eeb750e0bc841ed19377bb6e89fdd2ea981ae4fdd6cff3c02
p1_filesystem_sha256=0bd3c07b522cc5442feebe85bacf8ba67433e0321188a33525129ab7eb355a23
p2_raw_partition_sha256=b6b53b9c04d1469b87b1ac0d282f02748c3e8386891c9f97ed1a04a652786ef7
p3_filesystem_sha256=4e5d7d2646f8697440cab036e838c326cbc9e529f1a80991febd3361da73ada1
```

The complete image verifier passed first-boot storage, partition layout,
boot/matching payload, System, app/component checksums, Wi-Fi seed policy,
vendor/license audit, release-content audit, RGB565 matrix and bidirectional
emulator-catalog coverage.

`BUB-P7-06` remains open only for writing this newly rebuilt raw image to
media, independent block readback, the requested three cold boots and the
final rollback exercise. Publication remains gated by `BUB-P7-07` and
`BUB-P7-08`.
