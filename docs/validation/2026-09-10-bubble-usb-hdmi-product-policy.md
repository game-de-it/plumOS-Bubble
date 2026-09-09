# Bubble USB / HDMI product policy

Date: 2026-09-10

## Decision

- The Bubble has one externally accessible USB connector. plumOS treats it as
  charge-only; USB host, USB device and ADB are not product features.
- ADB is omitted from both `NW Service` and `NW Information` on Bubble.
- HDMI is not a supported display output in the current Bubble product policy.
- These are device product exclusions, not silently missing common runtime
  features. They remain machine-readable in
  `config/frontend/start-menu-coverage.json` under `product_excluded`.

## Evidence and retained diagnostics

- The stock runtime exposes no entry in `/sys/class/udc` and no USB role-switch
  interface. It therefore cannot provide an honest USB-device/ADB route.
- The existing internal network-service backend continues to report ADB as
  `hardware_unavailable`. It is retained for diagnostics and future hardware
  investigation, but it is no longer exposed as a Bubble setting or status row.
- The device tree package contains an HDMI-oriented artifact, but that does not
  establish a supported physical HDMI route. No HDMI UI or acceptance claim is
  made for this product revision.
- Earlier physical charging validation observed charger disconnect/connect
  transitions without losing FE or Wi-Fi operation. This decision does not
  alter charging behavior.

## Acceptance remaining

After the frontend component is deployed and the device is restarted through
the normal FE path, verify on the physical LCD that neither `NW Service` nor
`NW Information` contains an ADB row. Close `BUB-P4-N03` only after that check.
