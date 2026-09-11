# Bubble v0.1.0-rc1 release bundle

Date: 2026-09-11

## Promotion basis

The maintainer accepted the exact release-candidate image after a physical SD
write, Saturn launch, Wi-Fi, managed checksum readback and three clean cold
boots. The tested raw image is promoted without changing its bytes:

```text
image=plumos-bubble-v0.1.0-rc1-sd-image.img
image_source_ref=0a3a3b6
image_sha256=be49fdc3f0ec9f5eeb750e0bc841ed19377bb6e89fdd2ea981ae4fdd6cff3c02
size=3036676096
```

The embedded build-time `publishable=no` marker is retained so physical
acceptance remains tied to the same SHA-256. `manifest.txt` records the later
maintainer promotion explicitly.

## Prepared files

The ignored local release directory is
`dist/plumos-bubble-release-v0.1.0-rc1/`. It contains bilingual release notes,
the build manifest, complete image-verifier output, the compressed image,
its individual checksum, the release promotion manifest and `SHA256SUMS`.

```text
archive=plumos-bubble-v0.1.0-rc1-sd-image.7z
archive_size=480810424
archive_sha256=3b03fb27896072042f9ceccb8367b6d6581ad6285b19418e403505fdbe184f67
archive_member=plumos-bubble-v0.1.0-rc1-sd-image.img
```

The archive passed `7zz t`; streaming extraction reproduced the accepted raw
image SHA-256. Every entry in the bundle `SHA256SUMS` passed independently.
The image verifier repeated filesystem, System A/B, p2, app/component,
credential, license/content, catalog and 114-core checks successfully.

## Publication result

The maintainer explicitly approved publication after the final README logo and
device screenshots were added. The public repository, `main` branch, annotated
tag and prerelease are available at:

```text
repository=https://github.com/game-de-it/plumOS-Bubble
release=https://github.com/game-de-it/plumOS-Bubble/releases/tag/v0.1.0-rc1
tag=v0.1.0-rc1
tagged_source=990ff92aff5c2490c568cfeb072ccef225c117ba
assets=7
```

All seven assets were downloaded through the public browser-download URLs with
GitHub authentication variables removed. Every file was byte-identical to the
local release bundle and the downloaded `SHA256SUMS` passed. The downloaded 7z
also passed `7zz t`; streaming its raw image member reproduced:

```text
archive_sha256=3b03fb27896072042f9ceccb8367b6d6581ad6285b19418e403505fdbe184f67
raw_image_sha256=be49fdc3f0ec9f5eeb750e0bc841ed19377bb6e89fdd2ea981ae4fdd6cff3c02
anonymous_public_download=result-ok
```

`BUB-P7-08` is therefore complete.
