# Bubble fast boot physical validation

Date: 2026-09-03 (Asia/Tokyo)  
Device: GKD Bubble  
System slot: `b`  
System source: `24635cc`  
App-layer source: `4804579`

## Scope

This validates the boot changes which move recovery Wi-Fi association, DHCP and
Dropbear startup behind frontend dispatch, keep boot-time app-layer validation
to critical metadata, and prevent the asynchronous network worker from
overwriting the final FAT boot-stage marker.

Storage observation remains synchronous because it decides whether a known
dirty SD2 may be scanned. It is passive: it does not repair the filesystem, and
the `observe` route no longer performs a global filesystem `sync`.

## Device evidence

The accepted cold boot had boot ID
`b070d1ae-54e9-4cd3-aff5-0ea157181c28` and an estimated boot epoch of
`1788438322`.

- `/flash/System/active-slot` was `b`.
- System B expected and read-back SHA-256 both matched
  `265e23495c5a36d3b8b37bd1917b00c6a24f2f15b54dd94d6ae1ea66a4568afb`.
- `/sbin/init` matched the host source SHA-256
  `85362d1c416c40166b052bc288f8169675f29099d53c3c65857fc9e5a64bfeb6`.
- The deployment record at
  `/storage/plumos/state/system-deploy/24635cc/SYSTEM.manifest` identifies the
  running System image as source `24635cc`.
- `/flash/plumos-probe/system-stage.txt` remained
  `S40_FRONTEND_SUPERVISOR_READY`; asynchronous `S38` completion no longer
  overwrote it.
- The current boot's last 14 init stages contained no `stage=E` entry.
- `/storage/plumos/logs/app-layer-verify.log` predates this boot, proving the
  12,373-file full verification was not repeated on the startup path.

Observed timing is relative to the kernel uptime clock or whole-second file
timestamps:

| Milestone | Time after boot |
| --- | ---: |
| final synchronous FAT stage `S40` | about 6 s |
| frontend process start | 6.33 s |
| background Wi-Fi/DHCP/SSH complete | about 10 s |
| frontend log active | about 11 s |
| `/tmp/plumos-fe-ready` | about 12 s |

The stage order was:

```text
S30_SYSTEM_ENTRY
S31_STORAGE_MOUNTED
S32_FLASH_MOUNTED
S33_FRAMEBUFFER_MARKER_DRAWN
S34_RECOVERY_NETWORK_BACKGROUND_DISPATCHED
S39_APP_LAYER_METADATA_READY
S34_WIFI_MODULE_LOADED
S40_FRONTEND_SUPERVISOR_READY
S41_FRONTEND_START attempt=0
S35_WIFI_INTERFACE_READY
S36_WPA_STARTED
S37_WIFI_ASSOCIATED
S38_RECOVERY_SSH_READY ip=192.168.10.101 port=22
S38_RECOVERY_NETWORK_BACKGROUND_FINISHED result=connected ip=192.168.10.101
```

This establishes that frontend startup is no longer gated by Wi-Fi completion.
At inspection time the frontend process was alive, Wi-Fi held
`192.168.10.101/24`, and Dropbear was listening after the background worker
completed.

## Preservation and mount state

The following mutable files retained their pre-deployment SHA-256 values:

| File | SHA-256 |
| --- | --- |
| `config/system/settings.json` | `043c0c97ebb22cabed0106fed336e8c26c3f10f7eee8d0aa97f8bfa87daf7348` |
| `config/frontend/settings.json` | `cb900f198b08006c0f2c1fd739729a36007713944dde5847e22d14f9ab075bec` |
| `config/network/services.conf` | `6d224fdf974f5354ec35f88c9f4adcd20b169556ab1ccd5c534bb2022cc60b41` |
| `config/wpa_supplicant.conf` | `fece399eff59eb721dff8aa2e5cc3342a72375cfd8556af408d08def4fc6cae3` |

`/` and `/flash` were read-only, while `/storage` was read-write. SD2 retained
its prior dirty evidence and was mounted read-only at `/run/media/sd2`; no
automatic repair was attempted by the System startup path.

The earlier external-initramfs path was a separate exception: even after
provisioning had completed it reran `e2fsck -pf`, `resize2fs`, and
`fsck.fat -a` on every boot. On this boot, p4 had its dirty bit removed by that
path before System startup. This is not part of `plumos-storage-health observe`
and is not accepted as the normal boot policy. The follow-up clean-shutdown
fast path is recorded below and still requires a physical reboot gate.

## Follow-up clean storage fast path

Source after this physical observation adds the V90S-style distinction between
clean normal startup and recovery startup:

- terminal shutdown/reboot writes paired p3/p4 clean markers, syncs, explicitly
  unmounts p4, then remounts p3 and p1 read-only;
- external initramfs accepts the normal path whenever provisioning is complete
  and fixed geometry/type/label checks pass;
- completed startup skips `e2fsck`, `resize2fs`, and `fsck.fat` regardless of
  clean-marker state; FAT repair is a user-directed host action;
- only incomplete first provisioning or its authorized resume path may run the
  synchronous resize/repair tools;
- both markers are consumed before mutable storage is handed to System so a
  crash cannot reuse stale clean-shutdown evidence.

Host fixtures cover first provisioning, interrupted provisioning, normal
repair/resume, clean fast-path geometry validation, marker creation and p4
unmount ordering. Long first-provision/update work receives visible progress;
normal boot remains the common plumOS logo followed directly by FE. Physical
deployment and the next normal reboot are pending.

The first transition deployment exposed a boot-contract defect before external
initramfs entry. The replacement initramfs was 4,034,371 bytes, 444 bytes larger
than the prior 4,033,927-byte file, while the installed `uEnv.txt` still passed
the old `initrdsize=0x3d8d87` to `booti`. U-Boot displayed the vendor Bubble
logo, but the truncated gzip never reached the plumOS logo or `S21`. The
instrumented external-initramfs boot script now assigns `initrdsize` from
U-Boot's `${filesize}` immediately after a successful load. Offline p1 repair
was applied and read back with active slot A. The following boot reached
`S40_FRONTEND_SUPERVISOR_READY`, associated Wi-Fi, and started the frontend
renderer loop, but the panel remained on the common plumOS logo. This boot is
not counted as normal-path acceptance.

The forced power-off after that observation left p3 ext4 with a corrupted
orphan list and allocation-summary mismatches. Read-only inspection identified
the two unlinked inodes as replaced executable images rather than mutable user
data: an old 2,108,608-byte static BusyBox and an old 265,456-byte frontend.
Both inode payloads, an ext4 metadata image, and the active configuration were
copied to the host before repair. The installed frontend binary still matched
its managed checksum
`fd181d901f2cd09be448faa5b6b325885e8d2b96b08aee60a0701c91f1e3577f`.

Offline `e2fsck` cleared only those orphan records, repaired their bitmap and
summary differences, and a subsequent forced read-only five-pass check returned
zero. `debugfs` then reported `Filesystem state: clean`, 1,152,257 free blocks,
and 505,731 free inodes. The preserved configuration hashes remained:

- frontend settings: `cb900f198b08006c0f2c1fd739729a36007713944dde5847e22d14f9ab075bec`;
- system settings: `043c0c97ebb22cabed0106fed336e8c26c3f10f7eee8d0aa97f8bfa87daf7348`;
- Wi-Fi configuration: `fece399eff59eb721dff8aa2e5cc3342a72375cfd8556af408d08def4fc6cae3`.

The latest `frontend-frame-stats.log` showed a successful initial render and
the expected 5-second TOP status refresh cadence (`0.2 fps` while idle); it did
not show a busy rendering loop. The next physical boot therefore remains the
gate for panel handoff, the 10-second delayed progress notice, and normal-path
timing after the ext4 repair.

Source `ae5501c` was then built and deployed offline with slot A retained as the
rollback. Each payload was copied under an incoming name, byte-compared with
the host artifact, renamed into place, synced, and SHA-256 read back before the
active slot was changed to B:

| Object | Installed SHA-256 |
| --- | --- |
| rollback System A | `43427fa2ff62a7d290101d0fa4bb5868367d3401c8298a55ff43263b499eaca6` |
| active System B | `6748e14553776292fa151615f709ceb7f77484ad9010bb2bba58cbcd05137505` |
| external initramfs | `3fd58c82444dd236221bb01f517a42cfff5c6bfe9c7b405d73eced70c118930d` |
| dynamic-size `boot.cmd` | `5ea363415ff1d7e60c50dd84699ea0718132a68db813fcb2a3d0c85fb3c32e65` |
| compiled `boot.scr` | `f5e1a00d681a28860f6a1cca919e0d8016cdfd9b2b3e7e1b5108b53f0096df9b` |

`uEnv.txt` now records the new fallback `initrdsize=0x3f8482`, while the
compiled boot script still contains `setenv initrdsize ${filesize}`. Both
per-slot checksum files passed on the mounted FAT volume. After deployment,
p3 again passed a forced read-only five-pass check. macOS did not grant the
p1 raw device read permission for an additional offline FAT checker run, so p1
acceptance here is limited to file readback plus a successful whole-disk
unmount and eject; no FAT repair was attempted.

## Remaining metadata work

The seed-level `/flash/System/SYSTEM.manifest` and
`/flash/plumos-image.manifest` intentionally still describe the original seed,
not the currently active deployed slot. Runtime identification therefore used
the active-slot file, per-slot SHA file, mounted init hash, and the immutable
deployment record together. The formal A/B updater must introduce slot-scoped
System manifests and switch their active identity atomically with the slot.
