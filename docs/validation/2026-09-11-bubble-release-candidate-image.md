# Bubble release-candidate image validation

Date: 2026-09-11

## Scope

The release-candidate validation image was rebuilt from detached source
`9c97b28` in the existing isolated clone at
`/private/tmp/plumos-bubble-release-clone-31f1933`. The tracked checkout was
clean. The build explicitly enabled the approved, captured Bubble vendor GPU
input and did not include Wi-Fi credentials, ROMs, saves, states, logs or other
user media.

The source includes the clean-build wrapper correction from `a96eb3b` and the
validated YabaSanshiro compiler correction from `4a8285f`. The latter restores
the Clang 14 build used by the working Bubble artifact instead of the regressed
GCC build. Before image generation, the standalone clean-build test and vendor
publishability audit both passed.

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

The app-layer manifest identifies version `0.1.0-rc1`, source `9c97b28`,
`publishable=true`, `release_complete=false`, and `user_media_included=false`.
The device-tuned Game Gear preset is present at
`factory-defaults/shaders/gamegear-lcd.glslp`; its SHA-256 is
`e5396c1e6b74dd3b4dc5be618285e9868b291bfddb7d9c7febba73f6d6cc4635`.
The packaged standalone YabaSanshiro ELF identifies Debian Clang 14.0.6 and
declares both `libEGL.so.1` and `libGLESv2.so.2` as runtime dependencies.

## Content and independent image verification

The verifier independently split the generated image, checked the FAT and
ext4 filesystems, matching boot bundle, dual System payloads, external
initramfs, first-boot storage contract, every component checksum and all 114
loadable cores. It also repeated the vendor/content and credential-free Wi-Fi
fixtures:

```text
bubble_wifi_first_connect_test=result-ok credential_free_scan=yes saved_config_preserved=yes
bubble_vendor_audit=result-ok inputs=5 checked_local=26 private_only=0 publishable=1
bubble_release_content=result-ok source_files=521 app_files=12481 approved_firmware=17 user_media=0 private_keys=0
bubble_frontend_probe_verify=result-ok image=/work/output/image/bubble-frontend-probe/plumOS-Bubble-0.1.0-rc1-full-stack-validation.img sha256=2a319d20ac460f36d3fca63fb4baa409a44b87f5c97946c6c062d5d663c35e5d personalized=no
```

The retained artifact is:

```text
file=plumOS-Bubble-0.1.0-rc1-full-stack-validation.img
image_size=3036676096
image_sha256=2a319d20ac460f36d3fca63fb4baa409a44b87f5c97946c6c062d5d663c35e5d
source_ref=9c97b28
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
