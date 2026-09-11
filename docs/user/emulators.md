# Emulator menus and hotkeys

## Button locations

- **Function 1 (F1, front face):** primary emulator-menu button
- **Function 2 (F2, top edge):** RetroArch screenshots and secondary functions

When opening a menu, remember that the primary key is Function 1 on the
**front face**, not Function 2 beside the top-edge SYS area.

## RetroArch (RA)

| Control | Action |
| --- | --- |
| Function 1 (front face) | Toggle the RetroArch menu |
| Function 2 (top edge) | Save a screenshot |
| `SELECT` + `START` | Exit to the frontend |
| `SELECT` + `L` | Load state |
| `SELECT` + `R` | Save state |
| `SELECT` + D-pad left/right | Previous/next state slot |
| `SELECT` + `Y` | Toggle FPS display |
| `SELECT` + `R2` | Toggle fast-forward |
| `SELECT` + `L2` | Toggle slow motion |

Screenshots are saved under `Images/` on SD1. Save-state compatibility varies
by game and core.

## PicoArch (PICO)

Press Function 1 (front face) to open the PicoArch menu. Use that menu for
exit, save and load. Not every RetroArch key combination applies to PicoArch.

## Standalone emulators (SA)

| Emulator | Menu control |
| --- | --- |
| PPSSPP (PSP) | Function 1 (front face) |
| PCSX-ReARMed standalone (PlayStation) | Function 1 (front face) |
| YabaSanshiro (Saturn) | Function 1 (front face) |
| OpenBOR | Function 1 (front face) |
| DraStic (Nintendo DS) | Function 1 (front face) for the normal menu |

In DraStic, Function 2 (top edge) + `START` opens a simple secondary menu. Use
the normal Function 1 menu for settings, saves and exit.

## PortMaster / Ports

Ports do not share a universal `SELECT` + `START` exit contract. Exit through
each game's own menu; controls vary by title.

## Pyxel

Pyxel applications have no RetroArch-style universal quick menu. Controls and
exit behavior belong to each application. If one stops responding, use the
device power menu to terminate it or reboot.

## Game Gear frontend (GGFE)

Launch it from `START` → `Apps` → `Game Gear`.

| Control | Action |
| --- | --- |
| D-pad left/right | Previous/next, repeat while held, wrap at either end |
| D-pad up/down | Jump five entries backward/forward |
| `A` | Launch |
| `X` | Toggle cartridge cases |
| `SELECT` | Open the GGFE menu |
| `B` / `START` | No action on the browser screen |

In the menu, use up/down for rows, left/right to change values, `A` to select,
and `B` or `SELECT` to close. After launch, the selected RA/PICO controls apply.

## Power operations

Normally return to the frontend and use its power menu. The power path attempts
to terminate a stuck emulator first, including when the game display is black.
Avoid forced power-off whenever the normal route remains available.
