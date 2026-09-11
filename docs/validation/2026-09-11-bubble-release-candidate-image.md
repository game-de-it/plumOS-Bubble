# Bubble release-candidate image validation

Date: 2026-09-11

## Scope

The release-candidate validation image was rebuilt from detached source
`a96eb3b` in the existing isolated clone at
`/private/tmp/plumos-bubble-release-clone-31f1933`. The tracked checkout was
clean. The build explicitly enabled the approved, captured Bubble vendor GPU
input and did not include Wi-Fi credentials, ROMs, saves, states, logs or other
user media.

The first attempt at source `97ed867` found a macOS Bash 3.2 nounset failure in
the standalone aggregate wrapper. Source `a96eb3b` fixes that clean-build
failure by keeping the forwarded argument array non-empty. Its regression test
and shell syntax check passed before the complete build was restarted.

## Complete build result

The top-level release path rebuilt the System, external initramfs and all ten
managed app-layer components, including all 114 libretro cores, 20 PicoArch
routes, five standalone runtimes, Pyxel and PortMaster. The integrated gates
reported:

```text
bubble_picoarch_rgb565_matrix=result-ok routes=20 rgb565=18 core_byteswap=6 route_overrides=5 xrgb8888=2 compat=1
bubble_emulator_catalog=result-ok systems=97 profiles=196 retroarch_ids=116 picoarch_ids=20 standalone_ids=5 release_complete=no
bubble_app_layer=result-ok
```

The app-layer manifest identifies version `0.1.0-rc1`, source `a96eb3b`,
`publishable=true`, `release_complete=false`, and `user_media_included=false`.
The device-tuned Game Gear preset is present at
`factory-defaults/shaders/gamegear-lcd.glslp`; its SHA-256 is
`e5396c1e6b74dd3b4dc5be618285e9868b291bfddb7d9c7febba73f6d6cc4635`.

## Content and independent image verification

The verifier independently split the generated image, checked the FAT and
ext4 filesystems, matching boot bundle, dual System payloads, external
initramfs, first-boot storage contract, every component checksum and all 114
loadable cores. It also repeated the vendor/content and credential-free Wi-Fi
fixtures:

```text
bubble_wifi_first_connect_test=result-ok credential_free_scan=yes saved_config_preserved=yes
bubble_vendor_audit=result-ok inputs=5 checked_local=26 private_only=0 publishable=1
bubble_release_content=result-ok source_files=519 app_files=12469 approved_firmware=17 user_media=0 private_keys=0
bubble_frontend_probe_verify=result-ok image=/work/output/image/bubble-frontend-probe/plumOS-Bubble-0.1.0-rc1-full-stack-validation.img sha256=9c678b3a4aa6e400a92806bce5eeea300704abf48b32f81fdca22c5de3ea10de personalized=no
```

The retained artifact is:

```text
file=plumOS-Bubble-0.1.0-rc1-full-stack-validation.img
image_size=3036676096
image_sha256=9c678b3a4aa6e400a92806bce5eeea300704abf48b32f81fdca22c5de3ea10de
source_ref=a96eb3b
minimum_card_size_mib=14336
final_partition_contract=host-candidate
publishable=no
```

Only this newest `.img` remains under the main and isolated-clone image output
directories. It is deliberately a non-publishable host candidate: SD
write/readback and physical-device acceptance remain `BUB-P7-06`, user RC
approval remains `BUB-P7-07`, and publication still requires the explicit
`BUB-P7-08` approval.

No release was published by this validation.
