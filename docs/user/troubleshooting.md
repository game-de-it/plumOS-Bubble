# Troubleshooting

## A game is missing

1. Check its folder and extension in the [supported systems table](supported-systems.md).
2. With `SHOW EMPTY SYSTEM` off, a system is hidden until a ROM is recognized.
3. Avoid case-only duplicate folders, then refresh or reboot.
4. When using SD2, reseat it while powered off.

## Launch failure or black screen

- For discs, check BIOS files and every path referenced by `.cue` or `.m3u`.
- Match arcade ROM-set versions to the selected core.
- Press `SELECT` on the game and try another available core.
- Try Function 1 (front face) to open the emulator menu.
- Use the power menu to exit or reboot. Never start an FE and emulator together
  from SSH.

Two display owners can cause flicker and LCD image retention. Even for diagnosis,
use the normal frontend route to launch an emulator.

## Low or skipping audio

Check both frontend and emulator volume plus headphone detection. Heavy systems
such as N64 may require the Performance profile. Some scenes can still exceed
the RK3566 performance budget.

## SD2 problems

Reseat SD2 while powered off. For a recognized but suspect FAT32 card, use
`START` → `Apps` → `Repair SD2`; it cannot target SYS. If a computer requests
repair or hardware failure is suspected, back up important files first.

## Wi-Fi or scraping

After reboot, enable Wi-Fi and check the IP and clock. Rescan if the SSID is
missing, and check router distance and band. Logs are under `plumos/logs/` on SD1.

## Forced power-off

Try the normal power menu first and wait briefly if the screen turns off before
the LED. Forced power-off can damage filesystems and is a last resort.
