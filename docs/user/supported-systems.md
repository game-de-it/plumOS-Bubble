# Supported Systems, ROM Directories, Extensions, and Emulators

This table lists every system currently enabled in plumOS for GKD Bubble.
Place ROMs below `Roms/` on SD1 (the top SYS slot) or SD2 (the bottom SD2
slot). The first directory is recommended. Other names are recognized aliases,
but using multiple aliases for one system can create duplicate entries.

Extensions are case-insensitive. Recognition does not guarantee compatibility:
a correct BIOS, ROM set, disc layout, or game-specific support may still be
required. Prefer `.cue`, `.gdi`, or `.m3u` where a disc has multiple files.

RA means RetroArch, PICO means PicoArch, and SA means Standalone. Press SELECT
on a game to choose another launch method listed in its row.

## Supported systems (88)

| System | ROM directories (first recommended) | Extensions | Launch methods, emulators, and cores |
| --- | --- | --- | --- |
| NES | `Roms/FC/`<br>`Roms/nes/`<br>`Roms/famicom/` | `.nes`, `.unf`, `.unif`, `.zip`, `.7z` | **Default:** RA `quicknes`<br>RA: `fceumm`, `nestopia`<br>PICO: `quicknes`, `fceumm`, `nestopia` |
| FDS | `Roms/FDS/`<br>`Roms/FC/`<br>`Roms/fds/`<br>`Roms/_etc/fds/` | `.fds`, `.zip`, `.7z` | **Default:** RA `fceumm`<br>RA: `nestopia`<br>PICO: `fceumm`, `nestopia` |
| SFC | `Roms/SFC/`<br>`Roms/sfc/`<br>`Roms/snes/` | `.sfc`, `.smc`, `.fig`, `.bs`, `.swc`, `.zip`, `.7z` | **Default:** RA `snes9x2005`<br>RA: `snes9x`, `chimerasnes`, `mednafen_supafaust`, `snes9x2002`, `snes9x2005_plus`, `snes9x2010`<br>PICO: `snes9x2005`, `snes9x`, `chimerasnes`, `mednafen_supafaust`, `snes9x2002`, `snes9x2005_plus`, `snes9x2010` |
| GB | `Roms/GB/`<br>`Roms/gb/` | `.gb`, `.zip`, `.7z` | **Default:** RA `gambatte`<br>RA: `mgba`, `gearboy`, `tgbdual`, `vbam`<br>PICO: `gambatte`, `gearboy`, `vbam` |
| GBC | `Roms/GBC/`<br>`Roms/GB/`<br>`Roms/gbc/` | `.gbc`, `.zip`, `.7z` | **Default:** RA `gambatte`<br>RA: `mgba`, `gearboy`, `tgbdual`, `vbam`<br>PICO: `gambatte`, `gearboy`, `vbam` |
| GBA | `Roms/GBA/`<br>`Roms/gba/` | `.gba`, `.zip`, `.7z` | **Default:** RA `gpsp`<br>RA: `mgba`, `mednafen_gba`, `meteor`, `vba_next`<br>PICO: `gpsp`, `mgba` |
| Mega Drive | `Roms/MD/`<br>`Roms/megadrive/`<br>`Roms/genesis/` | `.gen`, `.md`, `.smd`, `.bin`, `.zip`, `.7z` | **Default:** RA `genesis_plus_gx`<br>RA: `picodrive`<br>PICO: `genesis_plus_gx`, `picodrive` |
| Master System | `Roms/MS/`<br>`Roms/MD/`<br>`Roms/mastersystem/` | `.sms`, `.bin`, `.zip`, `.7z` | **Default:** RA `genesis_plus_gx`<br>RA: `picodrive`, `gearsystem`<br>PICO: `genesis_plus_gx`, `picodrive`, `gearsystem` |
| Game Gear | `Roms/GG/`<br>`Roms/GameGear/`<br>`Roms/MD/`<br>`Roms/gamegear/` | `.gg`, `.zip`, `.7z` | **Default:** RA `genesis_plus_gx`<br>RA: `picodrive`, `gearsystem`<br>PICO: `genesis_plus_gx`, `picodrive`, `gearsystem` |
| 32X | `Roms/THIRTYTWOX/`<br>`Roms/MD/`<br>`Roms/sega32x/`<br>`Roms/_etc/sega32x/` | `.32x`, `.bin`, `.zip`, `.7z` | **Default:** RA `picodrive`<br>PICO: `picodrive` |
| Sega CD | `Roms/SEGACD/`<br>`Roms/segacd/`<br>`Roms/megacd/`<br>`Roms/_etc/segacd/` | `.cue`, `.chd`, `.iso`, `.m3u`, `.bin` | **Default:** RA `genesis_plus_gx`<br>RA: `picodrive`<br>PICO: `genesis_plus_gx`, `picodrive` |
| PC Engine | `Roms/PCE/`<br>`Roms/pcengine/`<br>`Roms/tg16/` | `.pce`, `.sgx`, `.zip`, `.7z` | **Default:** RA `mednafen_pce_fast`<br>RA: `mednafen_pce`, `mednafen_supergrafx`<br>PICO: `mednafen_pce_fast`, `mednafen_supergrafx` |
| SuperGrafx | `Roms/SGX/`<br>`Roms/PCE/`<br>`Roms/supergrafx/`<br>`Roms/_etc/supergrafx/` | `.sgx`, `.pce`, `.zip`, `.7z` | **Default:** RA `mednafen_supergrafx`<br>RA: `mednafen_pce_fast`<br>PICO: `mednafen_supergrafx`, `mednafen_pce_fast` |
| PC Engine CD | `Roms/PCECD/`<br>`Roms/pcenginecd/`<br>`Roms/tg16cd/` | `.cue`, `.ccd`, `.chd`, `.toc`, `.iso`, `.m3u` | **Default:** RA `mednafen_pce_fast`<br>PICO: `mednafen_pce_fast` |
| PlayStation | `Roms/PS/`<br>`Roms/PSX/`<br>`Roms/psx/` | `.cue`, `.chd`, `.pbp`, `.m3u`, `.iso`, `.img`, `.bin`, `.mdf`, `.toc`, `.cbn`, `.ccd` | **Default:** RA `pcsx_rearmed`<br>RA: `km_duckswanstation_xtreme_amped`<br>SA: `pcsx_rearmed` |
| PSP | `Roms/PSP/`<br>`Roms/PPSSPP/`<br>`Roms/psp/` | `.iso`, `.cso`, `.chd`, `.pbp` | **Default:** SA `ppsspp` |
| Nintendo DS | `Roms/NDS/`<br>`Roms/nds/` | `.nds` | **Default:** SA `drastic` |
| N64 | `Roms/N64/`<br>`Roms/n64/` | `.z64`, `.n64`, `.v64`, `.zip`, `.7z` | **Default:** RA `parallel_n64`<br>RA: `mupen64plus_next` |
| Dreamcast | `Roms/DC/`<br>`Roms/dreamcast/` | `.chd`, `.cdi`, `.gdi`, `.m3u`, `.cue` | **Default:** RA `flycast_xtreme`<br>RA: `flycast` |
| Saturn | `Roms/SATURN/`<br>`Roms/saturn/` | `.ccd`, `.cue`, `.chd`, `.iso`, `.m3u`, `.bin` | **Default:** SA `yabasanshiro`<br>RA: `yabasanshiro`, `beetle_saturn` |
| Neo Geo | `Roms/NEOGEO/`<br>`Roms/neogeo/`<br>`Roms/_etc/neogeo/` | `.zip`, `.7z` | **Default:** RA `fbneo`<br>RA: `fbalpha2012`, `fbalpha2012_neogeo` |
| Neo Geo CD | `Roms/NEOCD/`<br>`Roms/neogeocd/`<br>`Roms/_etc/neogeocd/` | `.cue`, `.chd` | **Default:** RA `neocd` |
| NGP | `Roms/NGP/`<br>`Roms/ngp/` | `.ngp`, `.zip`, `.7z` | **Default:** RA `mednafen_ngp` |
| NGPC | `Roms/NGPC/`<br>`Roms/NGP/`<br>`Roms/ngpc/` | `.ngc`, `.ngpc`, `.zip`, `.7z` | **Default:** RA `mednafen_ngp` |
| WonderSwan | `Roms/WS/`<br>`Roms/WSC/`<br>`Roms/wonderswan/` | `.ws`, `.zip`, `.7z` | **Default:** RA `mednafen_wswan` |
| WonderSwan Color | `Roms/WSC/`<br>`Roms/wonderswancolor/` | `.wsc`, `.zip`, `.7z` | **Default:** RA `mednafen_wswan` |
| Atari Lynx | `Roms/LYNX/`<br>`Roms/lynx/`<br>`Roms/ATARI/Lynx/` | `.lnx`, `.lyx`, `.bll`, `.o`, `.zip`, `.7z` | **Default:** RA `mednafen_lynx`<br>RA: `handy` |
| Virtual Boy | `Roms/VB/`<br>`Roms/virtualboy/`<br>`Roms/_etc/viretualboy/` | `.vb`, `.vboy`, `.bin`, `.zip`, `.7z` | **Default:** RA `mednafen_vb` |
| Arcade | `Roms/ARCADE/`<br>`Roms/arcade/`<br>`Roms/ATARI/Arcade/` | `.zip`, `.7z` | **Default:** RA `mame2003_plus`<br>RA: `km_mame2003_xtreme`, `fbneo`, `fbalpha2012`, `mame2000`, `mba_mini` |
| FBNeo | `Roms/FBNEO/`<br>`Roms/ARCADE/`<br>`Roms/fbneo/` | `.zip`, `.7z` | **Default:** RA `fbneo` |
| CPS1 | `Roms/CPS1/`<br>`Roms/ARCADE/`<br>`Roms/cps1/` | `.zip`, `.7z` | **Default:** RA `fbneo`<br>RA: `fbalpha2012`, `fbalpha2012_cps1` |
| CPS2 | `Roms/CPS2/`<br>`Roms/ARCADE/`<br>`Roms/cps2/` | `.zip`, `.7z` | **Default:** RA `fbneo`<br>RA: `fbalpha2012`, `fbalpha2012_cps2` |
| CPS3 | `Roms/CPS3/`<br>`Roms/ARCADE/`<br>`Roms/cps3/` | `.zip`, `.7z` | **Default:** RA `fbneo`<br>RA: `fbalpha2012`, `fbalpha2012_cps3` |
| DOS | `Roms/DOS/`<br>`Roms/pc/` | `.dosz`, `.conf`, `.exe`, `.bat`, `.com`, `.zip` | **Default:** RA `dosbox_pure`<br>RA: `dosbox_pure_0.9.7` |
| EasyRPG | `Roms/EASYRPG/`<br>`Roms/easyrpg/`<br>`Roms/_etc/EASYRPG/` | `.easyrpg`, `.ldb`, `.zip` | **Default:** RA `easyrpg` |
| PICO-8 | `Roms/PICO8/`<br>`Roms/PICO/`<br>`Roms/pico-8/` | `.p8`, `.png` | **Default:** RA `fake08`<br>RA: `retro8` |
| ScummVM | `Roms/SCUMMVM/`<br>`Roms/scummvm/` | `.scummvm`, `.svm` | **Default:** RA `scummvm` |
| OpenBOR | `Roms/OPENBOR/`<br>`Roms/openbor/` | `.pak` | **Default:** SA `openbor` |
| Ports | `Roms/PORTS/`<br>`Roms/A30PORTS/`<br>`Roms/ports/` | `.sh` | **Default:** External `port` |
| MSX | `Roms/MSX/`<br>`Roms/msx/`<br>`Roms/msx2/` | `.rom`, `.mx1`, `.mx2`, `.dsk`, `.cas`, `.m3u`, `.zip`, `.7z` | **Default:** RA `fmsx`<br>RA: `bluemsx` |
| PC-88 | `Roms/PC88/`<br>`Roms/pc-8800/` | `.d88`, `.u88`, `.m3u`, `.zip` | **Default:** RA `quasi88` |
| PC-98 | `Roms/PC98/`<br>`Roms/pc-9800/`<br>`Roms/_etc/pc-9800/` | `.d88`, `.d98`, `.fdi`, `.hdi`, `.fdd`, `.2hd`, `.tfd`, `.hdm`, `.xdf`, `.dup`, `.nhd`, `.hdd`, `.thd`, `.hdn`, `.cmd`, `.m3u`, `.zip` | **Default:** RA `np2kai`<br>RA: `nekop2` |
| X68000 | `Roms/X68000/`<br>`Roms/x68000/` | `.dim`, `.img`, `.d88`, `.hdm`, `.dup`, `.2hd`, `.hdf`, `.xdf`, `.cmd`, `.m3u`, `.zip`, `.7z` | **Default:** RA `px68k` |
| TIC-80 | `Roms/TIC/`<br>`Roms/tic-80/` | `.tic` | **Default:** RA `tic80` |
| Atari 2600 | `Roms/ATARI2600/`<br>`Roms/atari2600/`<br>`Roms/ATARI/2600/` | `.a26`, `.bin`, `.zip`, `.7z` | **Default:** RA `stella2014` |
| Atari 7800 | `Roms/ATARI7800/`<br>`Roms/atari7800/`<br>`Roms/ATARI/7800/` | `.a78`, `.bin`, `.cdf`, `.zip`, `.7z` | **Default:** RA `prosystem` |
| Vectrex | `Roms/VECTREX/`<br>`Roms/vectrex/` | `.vec`, `.bin`, `.zip`, `.7z` | **Default:** RA `vecx` |
| Supervision | `Roms/SUPERVISION/`<br>`Roms/supervision/`<br>`Roms/_etc/supervision/` | `.sv`, `.bin`, `.zip`, `.7z` | **Default:** RA `potator` |
| Odyssey2 | `Roms/ODYSSEY2/`<br>`Roms/VIDEOPAC/`<br>`Roms/odyssey2/`<br>`Roms/_etc/odyssey2/` | `.bin`, `.zip`, `.7z` | **Default:** RA `o2em` |
| Game & Watch | `Roms/GW/`<br>`Roms/GAMEANDWATCH/`<br>`Roms/gameandwatch/`<br>`Roms/_etc/gameandwatch/` | `.mgw`, `.zip`, `.7z` | **Default:** RA `gw` |
| Pokemon Mini | `Roms/POKEMINI/`<br>`Roms/pokemini/`<br>`Roms/_etc/pokemini/` | `.min`, `.zip`, `.7z` | **Default:** RA `pokemini` |
| Doom | `Roms/DOOM/`<br>`Roms/doom/`<br>`Roms/_etc/doom/` | `.wad`, `.iwad`, `.pwad`, `.zip` | **Default:** RA `prboom` |
| Pyxel | `Roms/pyxel/`<br>`Roms/PYXEL/` | `.pyxapp`, `.py` | **Default:** Pyxel `bubble` |
| 3DO | `Roms/PANASONIC/`<br>`Roms/3do/`<br>`Roms/_etc/3do/` | `.iso`, `.chd`, `.bin`, `.cue` | **Default:** RA `opera` |
| Amiga | `Roms/AMIGA/`<br>`Roms/amiga/`<br>`Roms/_etc/amiga/` | `.adf`, `.adz`, `.dms`, `.fdi`, `.ipf`, `.hdf`, `.hdz`, `.lha`, `.slave`, `.info`, `.cue`, `.ccd`, `.nrg`, `.mds`, `.iso`, `.chd`, `.uae`, `.m3u`, `.zip`, `.7z`, `.rp9` | **Default:** RA `puae`<br>RA: `puae2021`, `uae4arm`, `km_puae_xtreme_amped` |
| Atari 5200 | `Roms/FIFTYTWOHUNDRED/`<br>`Roms/atari5200/`<br>`Roms/ATARI/5200/` | `.a52`, `.bin`, `.rom`, `.xfd`, `.atr`, `.atx`, `.cas`, `.car`, `.xex`, `.zip`, `.7z` | **Default:** RA `atari800`<br>RA: `a5200` |
| Atari 8-bit | `Roms/EIGHTHUNDRED/`<br>`Roms/atari800/`<br>`Roms/ATARI/800/` | `.atr`, `.xfd`, `.dcm`, `.cas`, `.bin`, `.a52`, `.atx`, `.car`, `.rom`, `.com`, `.xex`, `.m3u`, `.zip`, `.7z` | **Default:** RA `atari800` |
| Atari ST | `Roms/ATARIST/`<br>`Roms/atarist/`<br>`Roms/_etc/atarist/` | `.st`, `.msa`, `.zip`, `.stx`, `.dim`, `.ipf`, `.vhd`, `.gem`, `.ide`, `.m3u`, `.7z` | **Default:** RA `hatari` |
| Commodore 64 | `Roms/COMMODORE/`<br>`Roms/c64/`<br>`Roms/_etc/c64/` | `.d64`, `.d71`, `.d80`, `.d81`, `.d82`, `.g64`, `.g41`, `.x64`, `.t64`, `.tap`, `.prg`, `.p00`, `.crt`, `.bin`, `.zip`, `.gz`, `.m3u`, `.d6z`, `.d7z`, `.d8z`, `.g6z`, `.g4z`, `.x6z`, `.cmd`, `.vsf`, `.nib`, `.nbz` | **Default:** RA `vice_x64`<br>RA: `frodo` |
| Cannonball | `Roms/CANNONBALL/`<br>`Roms/cannonball/`<br>`Roms/_etc/cannonball/` | `.game`, `.88` | **Default:** RA `cannonball` |
| Cave Story | `Roms/CAVESTORY/`<br>`Roms/cavestory/`<br>`Roms/_etc/cavestory/` | `.exe` | **Default:** RA `nxengine` |
| ChaiLove | `Roms/CHAILOVE/`<br>`Roms/chailove/`<br>`Roms/_etc/chailove/` | `.chai`, `.chailove` | **Default:** RA `chailove` |
| Fairchild Channel F | `Roms/FAIRCHILD/`<br>`Roms/channelf/`<br>`Roms/_etc/channelf/` | `.bin`, `.chf`, `.rom`, `.zip`, `.7z` | **Default:** RA `freechaf` |
| ColecoVision | `Roms/COLECO/`<br>`Roms/coleco/`<br>`Roms/_etc/coleco/`<br>`Roms/_etc/colecovision/` | `.rom`, `.ri`, `.mx1`, `.mx2`, `.col`, `.dsk`, `.cas`, `.sg`, `.sc`, `.m3u`, `.zip`, `.7z` | **Default:** RA `bluemsx` |
| Amstrad CPC | `Roms/CPC/`<br>`Roms/amstradcpc/`<br>`Roms/_etc/amstradcpc/` | `.dsk`, `.sna`, `.zip`, `.tap`, `.cdt`, `.voc`, `.cpr`, `.m3u`, `.kcr`, `.7z` | **Default:** RA `crocods`<br>RA: `cap32` |
| Dinothawr | `Roms/DINOTHAWR/`<br>`Roms/dinothawr/`<br>`Roms/_etc/dinothawr/` | `.game` | **Default:** RA `dinothawr` |
| Intellivision | `Roms/INTELLIVISION/`<br>`Roms/intellivision/`<br>`Roms/_etc/intellivision/` | `.int`, `.bin`, `.rom`, `.zip`, `.7z` | **Default:** RA `freeintv` |
| Atari Jaguar | `Roms/JAGUAR/`<br>`Roms/atarijaguar/`<br>`Roms/ATARI/Jaguar/` | `.j64`, `.jag`, `.rom`, `.abs`, `.cof`, `.bin`, `.prg` | **Default:** RA `virtualjaguar` |
| LowRes NX | `Roms/LOWRESNX/`<br>`Roms/lowresnx/`<br>`Roms/_etc/lowresnx/` | `.nx` | **Default:** RA `lowresnx` |
| Lutro | `Roms/LUTRO/`<br>`Roms/lutro/`<br>`Roms/_etc/lutro/` | `.lutro`, `.love`, `.lua` | **Default:** RA `lutro` |
| MicroW8 | `Roms/MICROW8/`<br>`Roms/microw8/`<br>`Roms/_etc/microw8/` | `.uw8`, `.wasm` | **Default:** RA `uw8` |
| Game Music Emu | `Roms/MUSIC/`<br>`Roms/music/`<br>`Roms/_etc/music/` | `.ay`, `.gbs`, `.gym`, `.hes`, `.kss`, `.nsf`, `.nsfe`, `.sap`, `.spc`, `.vgm`, `.vgz`, `.zip` | **Default:** RA `gme` |
| PC-FX | `Roms/PCFX/`<br>`Roms/pcfx/`<br>`Roms/_etc/pcfx/` | `.cue`, `.ccd`, `.toc`, `.chd`, `.zip`, `.bin` | **Default:** RA `mednafen_pcfx` |
| Quake | `Roms/QUAKE/`<br>`Roms/quake/`<br>`Roms/_etc/quake/` | `.pak` | **Default:** RA `tyrquake` |
| SG-1000 | `Roms/SEGASGONE/`<br>`Roms/sg-1000/` | `.sg`, `.mv`, `.bin`, `.rom`, `.sms`, `.gg`, `.zip`, `.7z` | **Default:** RA `gearsystem`<br>RA: `bluemsx`, `genesis_plus_gx`, `picodrive` |
| Sharp X1 | `Roms/XONE/`<br>`Roms/x1/` | `.dx1`, `.zip`, `.2d`, `.2hd`, `.tfd`, `.d88`, `.88d`, `.hdm`, `.xdf`, `.dup`, `.tap`, `.cmd`, `.7z` | **Default:** RA `x1` |
| Thomson MO/TO | `Roms/THOMSON/`<br>`Roms/moto/`<br>`Roms/_etc/moto/` | `.fd`, `.sap`, `.k7`, `.m7`, `.m5`, `.rom` | **Default:** RA `theodore` |
| TI-83 | `Roms/TI83/`<br>`Roms/ti83/`<br>`Roms/_etc/ti83/` | `.8xp`, `.8xk`, `.8xg` | **Default:** RA `numero` |
| Uzebox | `Roms/UZEBOX/`<br>`Roms/uzebox/`<br>`Roms/_etc/uzebox/` | `.uze` | **Default:** RA `uzem` |
| Commodore VIC-20 | `Roms/VIC20/`<br>`Roms/vic20/`<br>`Roms/_etc/vic20/` | `.d64`, `.d6z`, `.d71`, `.d7z`, `.d80`, `.d81`, `.d82`, `.d8z`, `.g64`, `.g6z`, `.g41`, `.g4z`, `.x64`, `.x6z`, `.nib`, `.nbz`, `.d2m`, `.d4m`, `.t64`, `.tap`, `.tcrt`, `.prg`, `.p00`, `.crt`, `.bin`, `.cmd`, `.m3u`, `.vfl`, `.vsf`, `.zip`, `.7z`, `.gz`, `.20`, `.40`, `.60`, `.a0`, `.b0`, `.rom` | **Default:** RA `vice_xvic` |
| Dreamcast VMU | `Roms/VMU/`<br>`Roms/vmu/`<br>`Roms/_etc/vmu/` | `.vms`, `.dci`, `.bin` | **Default:** RA `vemulator` |
| Wolfenstein 3D | `Roms/WOLF3D/`<br>`Roms/wolf3d/` | `.wl6`, `.n3d`, `.sod`, `.sdm`, `.wl1`, `.pk3`, `.exe` | **Default:** RA `ecwolf` |
| ZX-81 | `Roms/ZXEIGHTYONE/`<br>`Roms/zx81/` | `.p`, `.tzx`, `.t81`, `.zip`, `.7z` | **Default:** RA `81` |
| ZX Spectrum | `Roms/ZXS/`<br>`Roms/zxspectrum/`<br>`Roms/_etc/zxspectrum/` | `.tzx`, `.tap`, `.z80`, `.rzx`, `.scl`, `.trd`, `.dsk`, `.dck`, `.sna`, `.szx`, `.zip`, `.gz`, `.udi`, `.mgt`, `.img`, `.7z` | **Default:** RA `fuse` |
| Arduboy | `Roms/ARDUBOY/`<br>`Roms/arduboy/` | `.hex` | **Default:** RA `arduous` |
| Mega Duck | `Roms/MEGADUCK/`<br>`Roms/megaduck/` | `.bin`, `.duck`, `.zip`, `.7z` | **Default:** RA `sameduck` |
| PuzzleScript | `Roms/PUZZLESCRIPT/`<br>`Roms/puzzlescript/` | `.pz`, `.pzp` | **Default:** RA `puzzlescript` |
| Super Bros War | `Roms/SUPERBROSWAR/`<br>`Roms/superbroswar/` | `.game` | **Default:** RA `km_superbroswar` |

## Currently disabled systems

These entries remain in the internal catalog but are not exposed as supported on
Bubble. Nintendo 3DS is excluded from the catalog because it is outside the RK3566
performance target. Java ME is disabled because device testing found no usable game.

| System | Internal ID |
| --- | --- |
| MAME 2003+ | `mame2003plus` |
| 2048 | `2048` |
| Elektronika BK | `bk` |
| Daphne | `daphne` |
| Flashback | `flashback` |
| Java ME | `j2me` |
| Mr.Boom | `mrboom` |
| Palm OS | `palm` |
| Rick Dangerous | `rickdangerous` |

## Related topics

- [Emulators and in-game controls](emulators.md)
- [SD cards and folders](storage.md)
- [BIOS, saves, and screenshots](save-data.md)

This file is generated from
`package/frontend-bubble/plumos/config/frontend/systems.json` by
`scripts/generate-bubble-supported-systems-doc.py`.
