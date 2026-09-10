# plumOS Bubble Runtime update contract

Bubble's START > System Settings > System Update route installs signed Runtime
packages without overwriting user-owned state.

## Package and request

- Package name: `plumos-bubble-runtime-<version>.tar.gz`
- Inbox: `/storage/user/updates`
- Target: `gkd-bubble`, `aarch64`, vendor runtime `bubble-stockos-r1`
- Signature: Ed25519 over canonical `META/manifest.json`
- Compatibility: installed source version, system ABI and runtime ABI must match
- Version order: comparable SemVer only; an equal or older target is rejected before a request is recorded
- The frontend action verifies and records the newest compatible package before
  invoking the normal safe reboot helper. It does not copy arbitrary files.

Build a signed package with:

```sh
./scripts/build-bubble-update-package.py \
  --type runtime \
  --input output/app-layer/bubble/plumos \
  --base-dir /path/to/previous/plumos \
  --version <new-version> \
  --base-version <installed-version> \
  --signing-key /secure/path/plumos-bubble-ed25519-private.pem
```

The private key is never part of the app layer or update archive. Unsigned
development archives require an explicit updater environment override and are
rejected by the normal START route.

## Transaction and rollback

At early frontend startup, before network services and library scanning, the
updater:

1. re-verifies package hash, signature, target and compatibility;
2. extracts and hashes every declared file in a private staging directory;
3. records the complete operation journal before changing the live Runtime;
4. moves each old managed file to `/storage/plumos/backups/update-previous` and
   atomically installs the staged replacement, with metadata installed last;
5. starts the frontend and waits for its DRM renderer-ready proof;
6. marks the Runtime healthy only after that proof.

If power is lost during the transaction, or another boot begins before the
renderer-ready proof, the journal restores every replaced/deleted file and
removes every newly added file. A failed request or signature never changes the
live Runtime.

## Ownership boundary

The updater owns packaged executables, emulator/core payloads, themes, fonts,
factory defaults, static frontend catalogs and standalone defaults. It does not
manage active frontend/system/RetroArch settings, saves, states, logs, ROMs,
BIOS, Wi-Fi credentials, keys, downloaded PortMaster content, or PortMaster's
installed-state record.

Bootloader, kernel, DTB, kernel modules and the stock System image are not
Runtime files. They remain full-image updates until Bubble's matching-set A/B
System layout and recovery acceptance are completed; Runtime packages cannot
write `/flash`.

Bubble follows the other plumOS series by shipping those immutable boot files as
a verified full SD image rather than adding a Bubble-only online boot updater.
