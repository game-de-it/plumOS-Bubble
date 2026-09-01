# Bubble first-boot storage provisioning host validation

Date: 2026-09-02
Scope: host fixture and image-source validation only; no physical SD write in
this gate.

## Contract

The validation seed contains p1 through p3 only:

```text
raw prefix  16 MiB       captured Bubble Rockchip boot substrate
p1          512 MiB FAT  PLUMBOOT, System A/B and boot files
p2           64 MiB raw  matching boot bundle boundary
p3         2304 MiB ext4 PLUMOS_SYS, managed app-layer and mutable state
```

After p1 and p3 authorization markers are read-only verified, first boot grows
p3 to exactly 8192 MiB and creates p4 at the next aligned sector through the
end of the card. Newly created p4 is FAT32 label `PLUMOS`. The minimum accepted
physical card capacity is 14336 MiB. Bubble currently uses an MBR partition
table, so unlike the V90S GPT implementation there is no backup GPT relocation
step.

p3 remains the device-managed runtime. p4 owns portable user data. It is
mounted below p3 as `/storage/user`; `/storage/Roms`, `/storage/BIOS`,
`/storage/Images`, and the other common user directories are non-destructive
links into that mount. No supplied ROM, BIOS, save, or credential is copied by
provisioning.

## Power-loss and unknown-media boundary

Before creating p4, the provisioner writes
`/plumos/provision/p4-create-authorized` to p3, syncs it, and unmounts p3. A
blank p4 can be formatted on resume only when that exact durable intent marker
exists and its start sector is correct. An existing p4 with an unknown start,
filesystem type, label, or a blank filesystem without intent is rejected.
Existing valid `PLUMOS` content is never reformatted.

Progress and failures use `S24A` through `S24D` and `E24A` through `E24D`.
After p3 is remounted, the complete log is copied to `first-boot.log`; later
boots use `last-boot.log`, preserving the completed first-boot evidence.

## Real block-device fixture

Command:

```sh
./tests/test-bubble-first-boot-storage.sh
```

The privileged disposable container creates 14 GiB sparse MBR disks and real
loop partitions. It verifies:

1. seed p3 expansion, ext4 resize, p4 creation, and FAT32 labeling;
2. a second run preserves the partition table and both filesystem UUIDs;
3. resume after the p3 partition entry changed but before `resize2fs`;
4. rejection of an unknown blank p4 without durable intent;
5. resume and format of the same blank p4 after the exact intent is present.

Result:

```text
bubble_first_boot_storage_test=result-ok
```

Physical first-boot timing, panel progress, kernel partition reread on the
Bubble SD controller, clean poweroff, and post-boot readback remain required.

## Full-stack validation image

The 2304 MiB p3 seed was assembled with the complete emulator stack and then
verified by partition readback. The base image passed System A/B, initramfs,
all seven component checksums, the 98-system/196-profile bidirectional FE
catalog gate, and the 114/114 libretro load smoke. A private derivative was
then created from the verified base by writing only the external
`wpa_supplicant.conf`; mode 0600 and exact content were read back before the
image was accepted.

```text
file=plumOS-Bubble-0.1.0-dev-full-stack-validation-wifi-private.img
size=3036676096
sha256=de03259a27fe9b24579a08d13d5f6716ba5fde39ffc2dce3b9d467b8bb6c53ee
source_ref=9424a2e
personalized=yes
publishable=no
```

The base and the previous QuickNES-era diagnostic image were removed after
the private image passed the same full readback. Exactly one `.img` remains.
