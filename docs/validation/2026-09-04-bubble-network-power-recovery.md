# Bubble network services and power recovery

Date: 2026-09-04 JST

## Scope

This validation covers source `d082d9c` on the running GKD Bubble. It verifies
the four frontend-visible network services, SD2 visibility through their normal
client routes, and the frontend Reboot and Shutdown routes. It does not
authorize a release.

## Failure and correction

The service menu could retain all four enabled flags while some daemons were not
running. The recovery SSH daemon starts before Wi-Fi owns an IPv4 address, while
FTP and Samba require the address and were not retried after association. SFTP
also had a stale dedicated-port contract even though the current plumOS series
shares the port-22 SSH subsystem.

The frontend launcher now performs one bounded background reconciliation after
IPv4 appears. SSH and SFTP share port 22, FTP uses port 21, Samba uses port 445,
and all three file-transfer routes expose the common `/storage` tree. The SD2
ROM and BIOS directories remain read-only bind mounts below that tree.

The power helper now treats a repeated identical pending request as success when
user storage has already been unmounted. This lets the frontend exit and leaves
the already-clean transaction for PID 1 to finalize instead of reporting a
false non-zero result.

An intermediate launcher deployment exposed a read-only SD2 regression because
compatibility-directory creation ran under `set -e`. Source `d082d9c` makes
those compatibility creates best-effort. The device recovered through the
normal external-initramfs path; no ROM, BIOS, save, or mutable configuration was
rewritten.

## Deployment integrity

The formal live deployment changed only 12 managed files. The captured network
BusyBox was deliberately retained because its rebuild is not byte reproducible.
Device verification results were:

- frontend component: 158 entries passed;
- network-services component: 242 entries passed;
- complete app layer: 12,373 entries passed, zero failures;
- frontend, system, Wi-Fi, and network-service settings matched their preserved
  pre-deployment SHA-256 values.

The initial metadata update attempt was rolled back automatically after its
rewrite logic truncated checksum paths containing spaces. The corrected update
replaced only the first hash field and preserved every path byte-for-byte. The
pre-deployment complete checksum was also run independently and passed all
12,373 entries, separating the tooling error from device payload state.

## Physical reboot acceptance

The user selected Reboot from the normal frontend. Evidence from the device:

- frontend action: `status=reboot requested`;
- SD2 BIOS and ROM bind mounts unbound successfully;
- SD2 mount unmounted successfully;
- p4 user storage unmounted and clean markers were written;
- PID 1 accepted `action=reboot`;
- the next external-initramfs boot recorded
  `previous_shutdown=clean automatic_repair=no`;
- slot A verified, System switched root, and the frontend returned on its first
  supervisor attempt;
- p4 returned read-write, while SD2 and both content binds returned read-only;
- the background service reconciliation completed on its first IPv4 attempt.

After reboot, ports 21, 22, and 445 were open and the obsolete port 2222 was
closed. The macOS client listed SD2 ROM directories through FTP and SFTP, then
mounted `//root@192.168.10.101/SDCARD` and listed the same SD2 tree through SMB.
All four service-status backends reported running and matched their live
processes.

## Physical shutdown acceptance

The user next selected Shutdown from the normal frontend. The frontend recorded
`status=shutdown complete poweroff`; the helper unbound both SD2 content mounts,
unmounted SD2 and p4, wrote the clean markers, and handed `action=shutdown` to
PID 1. The device powered off and was started again with the physical power
button.

The following cold boot again recorded
`previous_shutdown=clean automatic_repair=no`, verified slot A, restored the
frontend on its first supervisor attempt, mounted p4 read-write, and mounted SD2
and its ROM/BIOS binds read-only. The pending power request was absent. SSH,
FTP, SFTP, and Samba all returned to running state. A fresh macOS client test
listed the SD2 ROM tree through FTP and SFTP and directly mounted the Samba
`SDCARD` share.

## Remaining gate

Reboot and Shutdown are accepted. Charger transitions and suspend/resume remain
in `BUB-P4-P03`. The known pre-existing SD2 FAT dirty observation remains
warning only; startup did not scan or repair the card.
