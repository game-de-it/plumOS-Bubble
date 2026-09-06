# Bubble clean full-stack SD image rebuild

Date: 2026-09-06

## Result

A new non-publishable physical-device validation image was rebuilt from source
reference `eadb7f6` after the PortMaster adapter 29 renderer fix.

```text
file=plumOS-Bubble-0.1.0-dev-full-stack-validation.img
image_size=3036676096
image_sha256=47f28c1a23c1b39713e9f2cdc170f9b7bb1f7a7681111f44532e90c4275fe590
source_ref=eadb7f6
personalized=no
```

The image is a 2.8 GiB three-partition seed. First boot expands p3 from
2304 MiB to 8192 MiB and creates p4 in the remaining card space. The minimum
card size remains 14336 MiB.

## Clean-state boundary

The live device's accumulated `/storage/plumos/state` tree was not used as an
image input. The generated app layer contains only 28 KiB under `state`, which
is the generated frontend library index and empty PortMaster state directories.
Generated `logs`, `saves` and save-state directories are empty. There are no
device-matrix copies, app-deploy generations, deploy stages, incoming archives,
or rollback archives in the image.

The seed p3 filesystem is clean and has 90,222 free 4096-byte blocks before
first-boot expansion. The expansion to 8 GiB provides the runtime headroom that
was hidden on the long-lived development card by about 5.1 GiB of validation
history.

No Wi-Fi personalization was applied and `user_media_included=no`. The prior
Wi-Fi-personalized image and its two sidecars were removed after this image
passed verification, leaving one `.img` artifact under `output/image`.

## Verification

The independent image verifier passed after extracting p1, p2 and p3 from the
final image:

- exact Rockchip prefix and partition geometry;
- clean FAT32 and ext4 filesystems;
- System A/B equality and active slot A;
- external initramfs and first-boot provisioning tools;
- first-boot interruption/resume storage fixture;
- full app-layer and all ten component checksum files;
- 98 systems, 196 launch profiles and all 114 packaged libretro cores;
- the PicoArch RGB565 route table; and
- absence of NES user content.

The image verifier had stale assertions from before persistent RetroArch menu
settings and the Bubble-only GGFE Apps entry. They were aligned with the
already-enforced launcher and START-menu contracts. The image then completed
with `bubble_frontend_probe_verify=result-ok`.

## Publication boundary

This is a private hardware-validation image, not a release artifact. It includes
the captured Bubble Mali runtime required by PPSSPP, NDS, Pyxel and PortMaster.
Vendor redistribution review, remaining physical route acceptance and the
declared non-release-eligible DraStic firmware boundary remain open.
