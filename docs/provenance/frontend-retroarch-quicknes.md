# Bubble frontend / RetroArch / QuickNES provenance

## plumOS frontend

- Reference checkout: `/Users/kroot/plumOS-MF`
- Reference commit: `0095017c39226ad1c22bf8df852202673075936d`
- Reused common sources: controller UI, software DRM/fbdev renderer, library scanner,
  text UI, frontend helper, default theme, fonts, and translations.
- Bubble changes: `retrogame_joypad` discovery, physical-label A/B mapping,
  `/storage` ownership, Bubble identity, component-scoped libraries, and a minimal
  NES/RetroArch menu.
- Not reused: MF input daemon, virtual controller, hall sensor, rumble GPIO,
  headphone GPIO, MF backlight values, Mali userspace, or MF boot/update offsets.

The frontend remains covered by this repository's MIT license. Bundled font
notices are installed under `share/doc/plumos-frontend`.

## RetroArch

- Source: `https://github.com/libretro/RetroArch.git`
- Ref: `v1.22.2`
- Resolved commit: `69a4f0ea1e8aaf442ae4858f2e7f2b31a1776576`
- License file: upstream `COPYING`, installed as `licenses/RetroArch-COPYING`.
- Patch baseline: plumOS-MF patches 001 through 013 at the reference commit.
  Patch 001 is adapted to discover Bubble's `retrogame_joypad`; DRM stride,
  lifetime, nearest-neighbor, OSD, null-frame, and page-flip fixes remain common.
- Build contract: software plain DRM + RGUI + ALSA + udev. EGL, GLES, GBM,
  Vulkan, X11, Wayland, SDL, and networking are disabled.

## QuickNES

- Source: `https://github.com/libretro/QuickNES_Core.git`
- Commit: `058d66516ed3f1260b69e5b71cd454eb7e9234a3`
- License: upstream license discovered by the build and installed as
  `licenses/quicknes-LICENSE`.

No ROM, BIOS, save, or test content is copied into the app layer or image.
