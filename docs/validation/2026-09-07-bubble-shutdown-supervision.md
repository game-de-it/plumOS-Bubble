# Bubble shutdown supervision follow-up

Date: 2026-09-07

## Device observation

Shutdown was selected from a frontend restored after PortMaster validation.
The frontend stopped and the LCD went black. SSH, FTP, and Samba were no longer
available, while ICMP continued to answer. This proves that
`plumos-safe-shutdown` reached terminal service quiescence but PID 1 did not
consume the volatile `shutdown` request and execute the final power backend.

This matches the previously recorded `E81` boundary: the bounded PID 1 loop
treated intentional validation-hold hand-offs as frontend failures. After its
budget was exhausted it executed a recovery shell, which did not watch
`/run/plumos/power-action/request`. PortMaster cleanup also started a manual
frontend after a fixed three-second wait, allowing an otherwise healthy PID 1
frontend startup to race with an unsupervised renderer.

## Correction

- A launcher which entered a validation hold now continues the ordinary boot
  path in the same PID 1-owned process when the hold is released.
- PID 1 does not charge a frontend exit to the restart budget while the hold is
  present.
- PortMaster may start a compatibility frontend only when the persistent boot
  stage explicitly says `E81_FRONTEND_RESTART_LIMIT_RECOVERY_CONSOLE`; normal
  slow scanning can no longer create a second frontend.
- Recovery consoles keep a power-request watcher alive.
- Every terminal request arms an eight-second delayed app-layer finalizer. PID
  1 remains the preferred owner; the delayed path exits when PID 1 removes the
  request. Both paths use the same tmpfs atomic claim before remounting storage
  read-only and invoking forced reboot or poweroff.

The delayed finalizer is required for live compatibility with already written
images whose initramfs cannot be replaced by an app-layer update. The next SD
image also contains the PID 1 corrections and normally never needs it.

## Acceptance status

Host contracts cover hold continuation, restart-budget preservation,
recovery-console request monitoring, exclusive finalizer claim, action mismatch
rejection, and the explicit-E81 PortMaster fallback.

The user confirmed that Shutdown from the normally supervised frontend on
source `0334535` powered the device off. This closes the normal Shutdown visual
and physical-power boundary. The following boot must still attribute the
winning finalizer from persistent logs and confirm `previous_shutdown=clean`.
Physical Reboot and both terminal actions from an intentionally forced E81
recovery frontend remain open.
