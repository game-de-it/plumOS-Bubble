# Bubble Wi-Fi OFF persistence and recovery

Date: 2026-09-10 JST

## Scope

This completes `BUB-P4-N02`: credential-free first connection, saved credential
use, reconnect after boot, persistent Wi-Fi OFF, and bounded recovery through
the frontend route.

The clean image did not contain a personalized SSID or PSK. The user previously
confirmed that the repaired runtime-only scan configuration displayed access
points, completed the first connection, saved the selected network, and
reconnected after a physical power cycle. The repository image and factory
defaults remain credential-free.

## Persistent OFF test

The user selected Wi-Fi OFF in the frontend and then selected normal Reboot.
The next frontend boot displayed `NO WIFI`; Wi-Fi did not start merely because
a saved credential existed. The user then selected Wi-Fi ON and the device
reconnected through the saved configuration at `192.168.10.101`.

The final readback showed:

```text
wifi_enabled=true
wpa_state=COMPLETED
ip_address=192.168.10.101
```

No SSID or PSK is recorded in this document.

## Blocking OFF correction

The first physical OFF action made the frontend appear hung for approximately
eight seconds. The ordinary OFF path still used synchronous
`wpa_cli terminate`; Bubble's bcmdhd stack can block that driver-facing call
for roughly ten seconds. Suspend had already moved to bounded direct process
termination, but ordinary OFF had not.

Source `5aa5cae` makes ordinary OFF terminate only the owned DHCP and
wpa_supplicant PIDs, waiting at most 0.5 seconds before a final kill. It then
flushes the interface and writes the disconnected runtime status. Persistent
`wifi_enabled` policy and `wpa_supplicant.conf` remain caller-owned and are not
modified by the helper.

The contract test starts real disposable processes and proves that OFF kills
both, never calls `wpa_cli terminate`, preserves policy and credentials, and
writes `wpa_state=DISCONNECTED`. All 30 Bubble host tests passed.

The scoped live deployment updated the network helper and matching frontend
metadata. Frontend and complete app-layer checksums passed, while the device
settings and credential-file hashes remained unchanged. On the final physical
test, Wi-Fi OFF returned control to the frontend in about two seconds. Wi-Fi ON
then restored `COMPLETED` state and the same address. `BUB-P4-N02` is complete.
