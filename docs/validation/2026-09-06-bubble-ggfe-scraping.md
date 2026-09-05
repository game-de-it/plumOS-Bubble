# Bubble GGFE artwork scraping validation (2026-09-06)

## Scope

Game Gear artwork was fetched on the Bubble device so the physical GGFE
cartridge rendering can be reviewed.  The normal frontend was held with
`/run/plumos/validation/frontend-hold` and its renderer was confirmed stopped
before GGFE was started; the two frontends never owned the display together.

## Runtime defect and correction

The first `gamegear` fetch found all 20 ROMs but skipped all 20 before CRC
matching.  Network and DNS were healthy; the stock `/bin/busybox wget`
segfaulted on both tested HTTPS URLs.  Commit `9ada18a` packages the same
isolated curl runtime approach used by MF and Pixel2: curl, its recursive
AArch64 dependency closure, the dynamic loader, and CA certificates are now
part of the managed frontend component.  Device-side curl then fetched the
213127-byte Game Gear No-Intro DAT successfully.

Two valid No-Intro ROMs still had catalog-name mismatches between the DAT and
libretro thumbnail sets.  Commit `73a8699` adds CRC rescue entries for:

- `04302bbd`: Eternal Legend (Japan)
- `407ac070`: Putt & Putter (Japan, Korea)

Both Box Art and Title Screen rescue tables are packaged.  The existing
scraper remains CRC-based and does not guess artwork for unknown or bad-dump
content.

## Device result

The first Box Art pass downloaded 17 images.  The rescue pass downloaded the
two catalog-name mismatches, for a final result of 19 valid PNGs for 20 ROMs.
All 19 files passed an eight-byte PNG signature check.  A final plan reported:

```text
plan gamegear true simple_rom_crc 1 20 19 1 8/8/8 6/6/6
```

The only unresolved ROM is `super monaco gp 2 (j) [b1].gg`; its CRC is not in
the No-Intro DAT, consistent with the `[b1]` bad-dump label.  It deliberately
retains GGFE's `NO ARTWORK` plate rather than receiving a potentially incorrect
image.

The `73a8699` frontend component contains 212 managed entries and passed its
full device-side checksum verification.  Frontend settings, system settings,
and core overrides retained their pre-deployment hashes.  Rollback snapshots
remain under:

- `/storage/plumos/state/app-deploy/9ada18a-scraper/`
- `/storage/plumos/state/app-deploy/73a8699-gg-rescue/`

GGFE was restarted after scraping, recognized all 20 ROMs, and was the sole
owner of `/dev/dri/card0`.  Physical review of artwork composition and carousel
motion remains part of the broader GGFE acceptance task.
