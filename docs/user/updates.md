# Updates

Bubble update packages are checked for signature, device and version. The
updater rejects the same version and older-version downgrades.

1. Download the correct Bubble package and its published checksum.
2. Verify the checksum.
3. With SYS attached to a computer, copy it to `updates/` on the `PLUMOS`
   volume. Over the network share use `user/updates/`; the device path is
   `/storage/user/updates`.
4. Start the update from the `START` menu and confirm the shown version.
5. Do not power off or remove SYS until it completes.
6. After reboot, check the version, game list, Wi-Fi and saves.

Updates are designed to preserve ROMs, BIOS, saves, states, settings, themes,
downloaded ports and network information. Back up important user data anyway.
Rewriting the raw SD image is a fresh installation, not an in-place update.
