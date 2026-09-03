# Bubble ROCKNIX extension alignment

Date: 2026-09-04 JST

## Scope

This work aligns the Bubble frontend's ROM filename recognition with ROCKNIX
without weakening Bubble's launcher and shared-directory boundaries. It covers
catalog policy, host validation, a live atomic deployment, and an isolated
device scanner test. It does not claim that every real content format has been
launched by every core, and it does not authorize a release.

## References and update policy

The first comparison used the 123-system `es_systems.cfg` snapshot retained by
plumOS A30. The final policy was then checked against the official ROCKNIX
`distribution` repository at commit
`552674316206d815df7e6d755a4e307db2862005`. Its 139 files below
`config/emulators` produce canonical extension-map SHA-256
`ccc8959d791e99a3fde28586b8405b4c2252e19e5c189c004f006e9c905b9258`.

`rocknix-extension-policy.json` records all 98 Bubble systems. Every extension
for a mapped ROCKNIX system must be either present in the Bubble catalog or
retained as an exclusion with a non-empty reason. The host verifier enforces
that partition in both directions. `audit-bubble-rocknix-extensions.py` also
accepts a ROCKNIX checkout and fails when its commit, canonical map, system
count, mapped IDs, or extension sets drift from the recorded reference.

## Catalog result

Relative to the prior Bubble/MF catalog, 52 extensions were added across 18
systems:

- PC Engine CD, PlayStation, Dreamcast, DOS, MSX, PC-98, and X68000 disk or
  playlist formats;
- Atari 5200, Atari 800, Atari ST, and C64 formats;
- archive formats for Channel F, CPC, SG-1000, Sharp X1, ZX81, ZX Spectrum,
  and Mega Duck.

The current ROCKNIX comparison added PC-98 `.cmd` beyond the A30 snapshot.
Doom `.wad`, `.iwad`, and `.pwad` were already in Bubble and are now explicitly
required by policy. Pyxel remains a Bubble-specific system rather than being
misrepresented as a ROCKNIX mapping.

There are 30 explicit exclusions. They preserve correctness where a shared ROM
directory would otherwise assign the same archive to multiple systems, or
where Bubble's installed runtime cannot accept the ROCKNIX route. In
particular, Ports `.appimage` remains excluded because the Bubble PortMaster
launcher deliberately accepts only top-level `.sh` launchers; the ROCKNIX
`.doom` launcher descriptor is not raw PrBoom content.

## Host verification

The following gates passed:

- `scripts/verify-bubble-emulator-catalog.sh`: 98 systems, 196 profile
  occurrences, 116 RetroArch IDs, 20 PicoArch IDs, and 5 standalone IDs;
- `tests/test-bubble-rocknix-extension-policy.sh`: required-extension deletion
  and blank exclusion reasons are both rejected;
- `scripts/audit-bubble-rocknix-extensions.py` against the official checkout:
  commit `5526743`, 139 ROCKNIX systems, and 98 Bubble systems matched;
- frontend and complete app-layer assembly with source `cd01403`;
- JSON parsing and `git diff --check`.

## Device deployment and scanner proof

Source `cd01403` was deployed as a five-payload atomic update: `systems.json`,
the extension policy, frontend component manifest and checksum list, and the
root manifest. The device-global checksum list was updated from the existing
device copy rather than replacing it with unrelated rebuilt content. The
pre-deployment state is retained under
`/storage/plumos/backups/deploy-cd01403-before`.

The frontend component passed all 159 entries. The complete device app layer
passed all 12,374 entries. Frontend settings, system settings, Wi-Fi
credentials, and network-service settings retained their exact pre-deployment
SHA-256 values.

An isolated tree under `/run` contained one empty probe file for every newly
accepted system/extension pair. The deployed AArch64 scanner saw 52 files and
matched all 52 to the expected systems, with zero missing or unexpected
records. This proves filename recognition and routing to the system catalog;
real format parsing and gameplay remain separate acceptance work.

The actual SD2 ROM tree was inventoried read-only: 4,745 files were observed,
and no file in its corresponding system directory depended on the 52 new
extensions. The known FAT warning remains unchanged. No ROM, BIOS, save,
setting, library index, or SD2 filesystem content was written or repaired.

## Remaining gate

Future ROCKNIX changes can now be detected by running the source audit against
a refreshed official checkout and intentionally updating the policy. Real
content launch, display orientation/aspect, audio, input, save/state, and clean
frontend return remain under the wider `BUB-P6-05` and `BUB-P6-10` acceptance
gates.
