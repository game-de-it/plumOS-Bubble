# Bubble 3DS catalog exclusion

Date: 2026-09-10

## Decision

Nintendo 3DS is excluded from the Bubble system catalog and ROM scanning policy.
The RK3566 platform is outside the product performance target for 3DS emulation,
so Bubble must not display an unsupported 3DS entry or advertise a launch route.

This is a device-specific product exclusion, not an incomplete runtime port. It
therefore supersedes the earlier visible-unsupported policy recorded while the
98-system catalog was under development. Historical validation reports retain
their then-current counts; the active Bubble contract is 97 systems and 196
launch-profile occurrences.

## Mechanical contract

- `systems.json` contains no `3ds` system, ROM alias, artwork lookup, extension,
  or launch profile.
- `rocknix-extension-policy.json` has exactly the same 97 system IDs as the
  Bubble catalog and contains no 3DS rule.
- `runtime-coverage.json` is regenerated from the catalog and contains no 3DS
  record or route.
- catalog, runtime-coverage, app-layer, and frontend-probe gates require 97
  systems while retaining all 196 common plumOS launch-profile occurrences.
