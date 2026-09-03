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
- external initramfs accepts the fast path only when provisioning is complete,
  both clean markers exist, p4 is ready, and fixed geometry/type/label checks
  pass;
- accepted clean startup skips `e2fsck`, `resize2fs`, and `fsck.fat`;
- missing markers retain the existing synchronous repair/resume path;
- both markers are consumed before mutable storage is handed to System so a
  crash cannot reuse stale clean state.

Host fixtures cover first provisioning, interrupted provisioning, normal
repair/resume, clean fast-path geometry validation, marker creation and p4
unmount ordering. Physical deployment and the next clean reboot are pending.

The first transition deployment exposed a boot-contract defect before external
initramfs entry. The replacement initramfs was 4,034,371 bytes, 444 bytes larger
than the prior 4,033,927-byte file, while the installed `uEnv.txt` still passed
the old `initrdsize=0x3d8d87` to `booti`. U-Boot displayed the vendor Bubble
logo, but the truncated gzip never reached the plumOS logo or `S21`. The
instrumented external-initramfs boot script now assigns `initrdsize` from
U-Boot's `${filesize}` immediately after a successful load. Offline p1 repair
and physical boot acceptance remain pending; this failed boot is not counted as
clean-fast-path acceptance.

## Remaining metadata work

The seed-level `/flash/System/SYSTEM.manifest` and
`/flash/plumos-image.manifest` intentionally still describe the original seed,
not the currently active deployed slot. Runtime identification therefore used
the active-slot file, per-slot SHA file, mounted init hash, and the immutable
deployment record together. The formal A/B updater must introduce slot-scoped
System manifests and switch their active identity atomically with the slot.
