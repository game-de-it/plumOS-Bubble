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

## Physical acceptance

Source `8764e39` was deployed as a frontend-component delta. All 217 frontend
component files and all 12,460 managed app-layer files passed checksum
verification; the existing system, frontend and network-service setting hashes
were unchanged. The running frontend was not killed during deployment.

After a normal OS restart through the frontend, the user inspected the physical
LCD and confirmed that neither `NW Service` nor `NW Information` contained an
ADB row. `BUB-P4-N03` is complete.
