# Bubble release clean-build and content validation

Date: 2026-09-10

## Scope

`BUB-P7-05` was repeated from a normal detached clone rather than from the
maintainer's working tree. The clone was created under
`/private/tmp/plumos-bubble-release-clone-31f1933` and was clean when the
release-content audit ran.

The only ignored input copied into the clone was the hash-pinned captured
vendor source at `artifacts/vendor/bubble-stock-source`, which is required to
reproduce the matching Bubble boot/GPU substrate. Signing keys, Wi-Fi
credentials, logs, saves, states, ROM collections and user BIOS collections
were not copied.

## Clean-build result

The first top-level build exposed that the standalone aggregate still expected
old prebuilt inputs. Source `2379b87` fixed that clean-build defect and made the
aggregate build these five pinned runtime inputs before assembly:

- PCSX-ReARMed plus the staged SDL 1.2 compatibility GPU plugin
- YabaSanshiro
- DraStic plus its source-built integration libraries
- PPSSPP 1.20.4
- OpenBOR

PortMaster `2026.06.23-0015` was also rebuilt from its pinned official archive
and source-built compatibility libraries. The final app-layer checksum pass
covered all ten managed components. The catalog gates reported:

```text
bubble_picoarch_rgb565_matrix=result-ok routes=20 rgb565=18 core_byteswap=6 route_overrides=5 xrgb8888=2 compat=1
bubble_emulator_catalog=result-ok systems=97 profiles=196 retroarch_ids=116 picoarch_ids=20 standalone_ids=5 release_complete=no
bubble_app_layer=result-ok
```

The frontend, RetroArch and 114-core catalog outputs were produced earlier in
the same clean clone at `31f1933`. The only repository changes between
`31f1933` and the final image source `2379b87` are the standalone build and
release-audit scripts; no frontend, RetroArch, core source, package input or
configuration changed. Standalone and PortMaster were rebuilt after updating
the clone to `2379b87`. Each component manifest retains its own source or
upstream provenance.

## Content and license gates

The clean-checkout content audit and its vendor sub-audit passed:

```text
bubble_vendor_audit=result-ok inputs=5 checked_local=26 private_only=0 publishable=1
bubble_release_content=result-ok source_files=515 app_files=12459 approved_firmware=17 user_media=0 private_keys=0
```

The one-file difference reported after extracting the image is the generated
PortMaster installed-state seed; the extracted-image audit also passed with
`app_files=12460`. No user media or private key was present in either pass.
The app-layer manifest reports `publishable=true` and has no license blocker.

## Image and independent extraction

The clean clone produced:

```text
file=plumOS-Bubble-0.1.0-rc1-full-stack-validation.img
image_size=3036676096
image_sha256=4988ca40ee0125298d433759dbec7dadb6b0c5b656ccdb18854e4558f77cd22e
source_ref=2379b87
minimum_card_size_mib=14336
```

The verifier independently extracted and checked the partition filesystems,
matching boot bundle, System, initramfs, every app-layer component checksum,
first-boot storage behavior and credential-free Wi-Fi first-connect fixture.
Its final result was:

```text
bubble_frontend_probe_verify=result-ok image=/work/output/image/bubble-frontend-probe/plumOS-Bubble-0.1.0-rc1-full-stack-validation.img sha256=4988ca40ee0125298d433759dbec7dadb6b0c5b656ccdb18854e4558f77cd22e personalized=no
```

This file remains deliberately marked `publishable=no` because it is a
full-stack validation image with `final_partition_contract=host-candidate`.
The clean-build, completeness, license and content requirements of P7-05 are
complete; physical SD acceptance remains P7-06, user release-candidate
acceptance remains P7-07, and publication requires the explicit P7-08 approval.

No release was published by this validation.
