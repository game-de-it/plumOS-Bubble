# 対応システム・ROMフォルダ・拡張子・エミュレータ一覧

この一覧は、GKD Bubble版plumOSのフロントエンドで現在有効なシステムを
すべて掲載しています。ROMはSD1（本体上部のSYSスロット）またはSD2
（本体下部のSD2スロット）の`Roms/`以下へ置きます。各行の最初のフォルダ名を
推奨します。2つ目以降も別名として認識しますが、同じシステムのフォルダを複数
作ると重複表示される場合があります。

拡張子は大文字・小文字を区別しません。拡張子が認識されても、必要なBIOS、
ROM set、ディスク構成、ゲーム固有の互換性によって起動できない場合があります。
CD系は`.cue`、`.gdi`、`.m3u`など、トラック関係を保持できる形式を推奨します。

起動方法の略称はRA=RetroArch、PICO=PicoArch、SA=Standaloneです。
ゲーム選択中にSELECTを押すと、行に記載された別の起動方法を選べます。

## 対応システム（88件）

| システム | ROMフォルダ（先頭を推奨） | 対応拡張子 | 起動方法・エミュレータ／コア |
| --- | --- | --- | --- |
| NES | `Roms/FC/`<br>`Roms/nes/`<br>`Roms/famicom/` | `.nes`, `.unf`, `.unif`, `.zip`, `.7z` | **既定:** RA `quicknes`<br>RA: `fceumm`, `nestopia`<br>PICO: `quicknes`, `fceumm`, `nestopia` |
| FDS | `Roms/FDS/`<br>`Roms/FC/`<br>`Roms/fds/`<br>`Roms/_etc/fds/` | `.fds`, `.zip`, `.7z` | **既定:** RA `fceumm`<br>RA: `nestopia`<br>PICO: `fceumm`, `nestopia` |
| SFC | `Roms/SFC/`<br>`Roms/sfc/`<br>`Roms/snes/` | `.sfc`, `.smc`, `.fig`, `.bs`, `.swc`, `.zip`, `.7z` | **既定:** RA `snes9x2005`<br>RA: `snes9x`, `chimerasnes`, `mednafen_supafaust`, `snes9x2002`, `snes9x2005_plus`, `snes9x2010`<br>PICO: `snes9x2005`, `snes9x`, `chimerasnes`, `mednafen_supafaust`, `snes9x2002`, `snes9x2005_plus`, `snes9x2010` |
| GB | `Roms/GB/`<br>`Roms/gb/` | `.gb`, `.zip`, `.7z` | **既定:** RA `gambatte`<br>RA: `mgba`, `gearboy`, `tgbdual`, `vbam`<br>PICO: `gambatte`, `gearboy`, `vbam` |
| GBC | `Roms/GBC/`<br>`Roms/GB/`<br>`Roms/gbc/` | `.gbc`, `.zip`, `.7z` | **既定:** RA `gambatte`<br>RA: `mgba`, `gearboy`, `tgbdual`, `vbam`<br>PICO: `gambatte`, `gearboy`, `vbam` |
| GBA | `Roms/GBA/`<br>`Roms/gba/` | `.gba`, `.zip`, `.7z` | **既定:** RA `gpsp`<br>RA: `mgba`, `mednafen_gba`, `meteor`, `vba_next`<br>PICO: `gpsp`, `mgba` |
| Mega Drive | `Roms/MD/`<br>`Roms/megadrive/`<br>`Roms/genesis/` | `.gen`, `.md`, `.smd`, `.bin`, `.zip`, `.7z` | **既定:** RA `genesis_plus_gx`<br>RA: `picodrive`<br>PICO: `genesis_plus_gx`, `picodrive` |
| Master System | `Roms/MS/`<br>`Roms/MD/`<br>`Roms/mastersystem/` | `.sms`, `.bin`, `.zip`, `.7z` | **既定:** RA `genesis_plus_gx`<br>RA: `picodrive`, `gearsystem`<br>PICO: `genesis_plus_gx`, `picodrive`, `gearsystem` |
| Game Gear | `Roms/GG/`<br>`Roms/GameGear/`<br>`Roms/MD/`<br>`Roms/gamegear/` | `.gg`, `.zip`, `.7z` | **既定:** RA `genesis_plus_gx`<br>RA: `picodrive`, `gearsystem`<br>PICO: `genesis_plus_gx`, `picodrive`, `gearsystem` |
| 32X | `Roms/THIRTYTWOX/`<br>`Roms/MD/`<br>`Roms/sega32x/`<br>`Roms/_etc/sega32x/` | `.32x`, `.bin`, `.zip`, `.7z` | **既定:** RA `picodrive`<br>PICO: `picodrive` |
| Sega CD | `Roms/SEGACD/`<br>`Roms/segacd/`<br>`Roms/megacd/`<br>`Roms/_etc/segacd/` | `.cue`, `.chd`, `.iso`, `.m3u`, `.bin` | **既定:** RA `genesis_plus_gx`<br>RA: `picodrive`<br>PICO: `genesis_plus_gx`, `picodrive` |
| PC Engine | `Roms/PCE/`<br>`Roms/pcengine/`<br>`Roms/tg16/` | `.pce`, `.sgx`, `.zip`, `.7z` | **既定:** RA `mednafen_pce_fast`<br>RA: `mednafen_pce`, `mednafen_supergrafx`<br>PICO: `mednafen_pce_fast`, `mednafen_supergrafx` |
| SuperGrafx | `Roms/SGX/`<br>`Roms/PCE/`<br>`Roms/supergrafx/`<br>`Roms/_etc/supergrafx/` | `.sgx`, `.pce`, `.zip`, `.7z` | **既定:** RA `mednafen_supergrafx`<br>RA: `mednafen_pce_fast`<br>PICO: `mednafen_supergrafx`, `mednafen_pce_fast` |
| PC Engine CD | `Roms/PCECD/`<br>`Roms/pcenginecd/`<br>`Roms/tg16cd/` | `.cue`, `.ccd`, `.chd`, `.toc`, `.iso`, `.m3u` | **既定:** RA `mednafen_pce_fast`<br>PICO: `mednafen_pce_fast` |
| PlayStation | `Roms/PS/`<br>`Roms/PSX/`<br>`Roms/psx/` | `.cue`, `.chd`, `.pbp`, `.m3u`, `.iso`, `.img`, `.bin`, `.mdf`, `.toc`, `.cbn`, `.ccd` | **既定:** RA `pcsx_rearmed`<br>RA: `km_duckswanstation_xtreme_amped`<br>SA: `pcsx_rearmed` |
| PSP | `Roms/PSP/`<br>`Roms/PPSSPP/`<br>`Roms/psp/` | `.iso`, `.cso`, `.chd`, `.pbp` | **既定:** SA `ppsspp` |
| Nintendo DS | `Roms/NDS/`<br>`Roms/nds/` | `.nds` | **既定:** SA `drastic` |
| N64 | `Roms/N64/`<br>`Roms/n64/` | `.z64`, `.n64`, `.v64`, `.zip`, `.7z` | **既定:** RA `parallel_n64`<br>RA: `mupen64plus_next` |
| Dreamcast | `Roms/DC/`<br>`Roms/dreamcast/` | `.chd`, `.cdi`, `.gdi`, `.m3u`, `.cue` | **既定:** RA `flycast_xtreme`<br>RA: `flycast` |
| Saturn | `Roms/SATURN/`<br>`Roms/saturn/` | `.ccd`, `.cue`, `.chd`, `.iso`, `.m3u`, `.bin` | **既定:** SA `yabasanshiro`<br>RA: `yabasanshiro`, `beetle_saturn` |
| Neo Geo | `Roms/NEOGEO/`<br>`Roms/neogeo/`<br>`Roms/_etc/neogeo/` | `.zip`, `.7z` | **既定:** RA `fbneo`<br>RA: `fbalpha2012`, `fbalpha2012_neogeo` |
| Neo Geo CD | `Roms/NEOCD/`<br>`Roms/neogeocd/`<br>`Roms/_etc/neogeocd/` | `.cue`, `.chd` | **既定:** RA `neocd` |
| NGP | `Roms/NGP/`<br>`Roms/ngp/` | `.ngp`, `.zip`, `.7z` | **既定:** RA `mednafen_ngp` |
| NGPC | `Roms/NGPC/`<br>`Roms/NGP/`<br>`Roms/ngpc/` | `.ngc`, `.ngpc`, `.zip`, `.7z` | **既定:** RA `mednafen_ngp` |
| WonderSwan | `Roms/WS/`<br>`Roms/WSC/`<br>`Roms/wonderswan/` | `.ws`, `.zip`, `.7z` | **既定:** RA `mednafen_wswan` |
| WonderSwan Color | `Roms/WSC/`<br>`Roms/wonderswancolor/` | `.wsc`, `.zip`, `.7z` | **既定:** RA `mednafen_wswan` |
| Atari Lynx | `Roms/LYNX/`<br>`Roms/lynx/`<br>`Roms/ATARI/Lynx/` | `.lnx`, `.lyx`, `.bll`, `.o`, `.zip`, `.7z` | **既定:** RA `mednafen_lynx`<br>RA: `handy` |
| Virtual Boy | `Roms/VB/`<br>`Roms/virtualboy/`<br>`Roms/_etc/viretualboy/` | `.vb`, `.vboy`, `.bin`, `.zip`, `.7z` | **既定:** RA `mednafen_vb` |
| Arcade | `Roms/ARCADE/`<br>`Roms/arcade/`<br>`Roms/ATARI/Arcade/` | `.zip`, `.7z` | **既定:** RA `mame2003_plus`<br>RA: `km_mame2003_xtreme`, `fbneo`, `fbalpha2012`, `mame2000`, `mba_mini` |
| FBNeo | `Roms/FBNEO/`<br>`Roms/ARCADE/`<br>`Roms/fbneo/` | `.zip`, `.7z` | **既定:** RA `fbneo` |
| CPS1 | `Roms/CPS1/`<br>`Roms/ARCADE/`<br>`Roms/cps1/` | `.zip`, `.7z` | **既定:** RA `fbneo`<br>RA: `fbalpha2012`, `fbalpha2012_cps1` |
| CPS2 | `Roms/CPS2/`<br>`Roms/ARCADE/`<br>`Roms/cps2/` | `.zip`, `.7z` | **既定:** RA `fbneo`<br>RA: `fbalpha2012`, `fbalpha2012_cps2` |
| CPS3 | `Roms/CPS3/`<br>`Roms/ARCADE/`<br>`Roms/cps3/` | `.zip`, `.7z` | **既定:** RA `fbneo`<br>RA: `fbalpha2012`, `fbalpha2012_cps3` |
| DOS | `Roms/DOS/`<br>`Roms/pc/` | `.dosz`, `.conf`, `.exe`, `.bat`, `.com`, `.zip` | **既定:** RA `dosbox_pure`<br>RA: `dosbox_pure_0.9.7` |
| EasyRPG | `Roms/EASYRPG/`<br>`Roms/easyrpg/`<br>`Roms/_etc/EASYRPG/` | `.easyrpg`, `.ldb`, `.zip` | **既定:** RA `easyrpg` |
| PICO-8 | `Roms/PICO8/`<br>`Roms/PICO/`<br>`Roms/pico-8/` | `.p8`, `.png` | **既定:** RA `fake08`<br>RA: `retro8` |
| ScummVM | `Roms/SCUMMVM/`<br>`Roms/scummvm/` | `.scummvm`, `.svm` | **既定:** RA `scummvm` |
| OpenBOR | `Roms/OPENBOR/`<br>`Roms/openbor/` | `.pak` | **既定:** SA `openbor` |
| Ports | `Roms/PORTS/`<br>`Roms/A30PORTS/`<br>`Roms/ports/` | `.sh` | **既定:** External `port` |
| MSX | `Roms/MSX/`<br>`Roms/msx/`<br>`Roms/msx2/` | `.rom`, `.mx1`, `.mx2`, `.dsk`, `.cas`, `.m3u`, `.zip`, `.7z` | **既定:** RA `fmsx`<br>RA: `bluemsx` |
| PC-88 | `Roms/PC88/`<br>`Roms/pc-8800/` | `.d88`, `.u88`, `.m3u`, `.zip` | **既定:** RA `quasi88` |
| PC-98 | `Roms/PC98/`<br>`Roms/pc-9800/`<br>`Roms/_etc/pc-9800/` | `.d88`, `.d98`, `.fdi`, `.hdi`, `.fdd`, `.2hd`, `.tfd`, `.hdm`, `.xdf`, `.dup`, `.nhd`, `.hdd`, `.thd`, `.hdn`, `.cmd`, `.m3u`, `.zip` | **既定:** RA `np2kai`<br>RA: `nekop2` |
| X68000 | `Roms/X68000/`<br>`Roms/x68000/` | `.dim`, `.img`, `.d88`, `.hdm`, `.dup`, `.2hd`, `.hdf`, `.xdf`, `.cmd`, `.m3u`, `.zip`, `.7z` | **既定:** RA `px68k` |
| TIC-80 | `Roms/TIC/`<br>`Roms/tic-80/` | `.tic` | **既定:** RA `tic80` |
| Atari 2600 | `Roms/ATARI2600/`<br>`Roms/atari2600/`<br>`Roms/ATARI/2600/` | `.a26`, `.bin`, `.zip`, `.7z` | **既定:** RA `stella2014` |
| Atari 7800 | `Roms/ATARI7800/`<br>`Roms/atari7800/`<br>`Roms/ATARI/7800/` | `.a78`, `.bin`, `.cdf`, `.zip`, `.7z` | **既定:** RA `prosystem` |
| Vectrex | `Roms/VECTREX/`<br>`Roms/vectrex/` | `.vec`, `.bin`, `.zip`, `.7z` | **既定:** RA `vecx` |
| Supervision | `Roms/SUPERVISION/`<br>`Roms/supervision/`<br>`Roms/_etc/supervision/` | `.sv`, `.bin`, `.zip`, `.7z` | **既定:** RA `potator` |
| Odyssey2 | `Roms/ODYSSEY2/`<br>`Roms/VIDEOPAC/`<br>`Roms/odyssey2/`<br>`Roms/_etc/odyssey2/` | `.bin`, `.zip`, `.7z` | **既定:** RA `o2em` |
| Game & Watch | `Roms/GW/`<br>`Roms/GAMEANDWATCH/`<br>`Roms/gameandwatch/`<br>`Roms/_etc/gameandwatch/` | `.mgw`, `.zip`, `.7z` | **既定:** RA `gw` |
| Pokemon Mini | `Roms/POKEMINI/`<br>`Roms/pokemini/`<br>`Roms/_etc/pokemini/` | `.min`, `.zip`, `.7z` | **既定:** RA `pokemini` |
| Doom | `Roms/DOOM/`<br>`Roms/doom/`<br>`Roms/_etc/doom/` | `.wad`, `.iwad`, `.pwad`, `.zip` | **既定:** RA `prboom` |
| Pyxel | `Roms/pyxel/`<br>`Roms/PYXEL/` | `.pyxapp`, `.py` | **既定:** Pyxel `bubble` |
| 3DO | `Roms/PANASONIC/`<br>`Roms/3do/`<br>`Roms/_etc/3do/` | `.iso`, `.chd`, `.bin`, `.cue` | **既定:** RA `opera` |
| Amiga | `Roms/AMIGA/`<br>`Roms/amiga/`<br>`Roms/_etc/amiga/` | `.adf`, `.adz`, `.dms`, `.fdi`, `.ipf`, `.hdf`, `.hdz`, `.lha`, `.slave`, `.info`, `.cue`, `.ccd`, `.nrg`, `.mds`, `.iso`, `.chd`, `.uae`, `.m3u`, `.zip`, `.7z`, `.rp9` | **既定:** RA `puae`<br>RA: `puae2021`, `uae4arm`, `km_puae_xtreme_amped` |
| Atari 5200 | `Roms/FIFTYTWOHUNDRED/`<br>`Roms/atari5200/`<br>`Roms/ATARI/5200/` | `.a52`, `.bin`, `.rom`, `.xfd`, `.atr`, `.atx`, `.cas`, `.car`, `.xex`, `.zip`, `.7z` | **既定:** RA `atari800`<br>RA: `a5200` |
| Atari 8-bit | `Roms/EIGHTHUNDRED/`<br>`Roms/atari800/`<br>`Roms/ATARI/800/` | `.atr`, `.xfd`, `.dcm`, `.cas`, `.bin`, `.a52`, `.atx`, `.car`, `.rom`, `.com`, `.xex`, `.m3u`, `.zip`, `.7z` | **既定:** RA `atari800` |
| Atari ST | `Roms/ATARIST/`<br>`Roms/atarist/`<br>`Roms/_etc/atarist/` | `.st`, `.msa`, `.zip`, `.stx`, `.dim`, `.ipf`, `.vhd`, `.gem`, `.ide`, `.m3u`, `.7z` | **既定:** RA `hatari` |
| Commodore 64 | `Roms/COMMODORE/`<br>`Roms/c64/`<br>`Roms/_etc/c64/` | `.d64`, `.d71`, `.d80`, `.d81`, `.d82`, `.g64`, `.g41`, `.x64`, `.t64`, `.tap`, `.prg`, `.p00`, `.crt`, `.bin`, `.zip`, `.gz`, `.m3u`, `.d6z`, `.d7z`, `.d8z`, `.g6z`, `.g4z`, `.x6z`, `.cmd`, `.vsf`, `.nib`, `.nbz` | **既定:** RA `vice_x64`<br>RA: `frodo` |
| Cannonball | `Roms/CANNONBALL/`<br>`Roms/cannonball/`<br>`Roms/_etc/cannonball/` | `.game`, `.88` | **既定:** RA `cannonball` |
| Cave Story | `Roms/CAVESTORY/`<br>`Roms/cavestory/`<br>`Roms/_etc/cavestory/` | `.exe` | **既定:** RA `nxengine` |
| ChaiLove | `Roms/CHAILOVE/`<br>`Roms/chailove/`<br>`Roms/_etc/chailove/` | `.chai`, `.chailove` | **既定:** RA `chailove` |
| Fairchild Channel F | `Roms/FAIRCHILD/`<br>`Roms/channelf/`<br>`Roms/_etc/channelf/` | `.bin`, `.chf`, `.rom`, `.zip`, `.7z` | **既定:** RA `freechaf` |
| ColecoVision | `Roms/COLECO/`<br>`Roms/coleco/`<br>`Roms/_etc/coleco/`<br>`Roms/_etc/colecovision/` | `.rom`, `.ri`, `.mx1`, `.mx2`, `.col`, `.dsk`, `.cas`, `.sg`, `.sc`, `.m3u`, `.zip`, `.7z` | **既定:** RA `bluemsx` |
| Amstrad CPC | `Roms/CPC/`<br>`Roms/amstradcpc/`<br>`Roms/_etc/amstradcpc/` | `.dsk`, `.sna`, `.zip`, `.tap`, `.cdt`, `.voc`, `.cpr`, `.m3u`, `.kcr`, `.7z` | **既定:** RA `crocods`<br>RA: `cap32` |
| Dinothawr | `Roms/DINOTHAWR/`<br>`Roms/dinothawr/`<br>`Roms/_etc/dinothawr/` | `.game` | **既定:** RA `dinothawr` |
| Intellivision | `Roms/INTELLIVISION/`<br>`Roms/intellivision/`<br>`Roms/_etc/intellivision/` | `.int`, `.bin`, `.rom`, `.zip`, `.7z` | **既定:** RA `freeintv` |
| Atari Jaguar | `Roms/JAGUAR/`<br>`Roms/atarijaguar/`<br>`Roms/ATARI/Jaguar/` | `.j64`, `.jag`, `.rom`, `.abs`, `.cof`, `.bin`, `.prg` | **既定:** RA `virtualjaguar` |
| LowRes NX | `Roms/LOWRESNX/`<br>`Roms/lowresnx/`<br>`Roms/_etc/lowresnx/` | `.nx` | **既定:** RA `lowresnx` |
| Lutro | `Roms/LUTRO/`<br>`Roms/lutro/`<br>`Roms/_etc/lutro/` | `.lutro`, `.love`, `.lua` | **既定:** RA `lutro` |
| MicroW8 | `Roms/MICROW8/`<br>`Roms/microw8/`<br>`Roms/_etc/microw8/` | `.uw8`, `.wasm` | **既定:** RA `uw8` |
| Game Music Emu | `Roms/MUSIC/`<br>`Roms/music/`<br>`Roms/_etc/music/` | `.ay`, `.gbs`, `.gym`, `.hes`, `.kss`, `.nsf`, `.nsfe`, `.sap`, `.spc`, `.vgm`, `.vgz`, `.zip` | **既定:** RA `gme` |
| PC-FX | `Roms/PCFX/`<br>`Roms/pcfx/`<br>`Roms/_etc/pcfx/` | `.cue`, `.ccd`, `.toc`, `.chd`, `.zip`, `.bin` | **既定:** RA `mednafen_pcfx` |
| Quake | `Roms/QUAKE/`<br>`Roms/quake/`<br>`Roms/_etc/quake/` | `.pak` | **既定:** RA `tyrquake` |
| SG-1000 | `Roms/SEGASGONE/`<br>`Roms/sg-1000/` | `.sg`, `.mv`, `.bin`, `.rom`, `.sms`, `.gg`, `.zip`, `.7z` | **既定:** RA `gearsystem`<br>RA: `bluemsx`, `genesis_plus_gx`, `picodrive` |
| Sharp X1 | `Roms/XONE/`<br>`Roms/x1/` | `.dx1`, `.zip`, `.2d`, `.2hd`, `.tfd`, `.d88`, `.88d`, `.hdm`, `.xdf`, `.dup`, `.tap`, `.cmd`, `.7z` | **既定:** RA `x1` |
| Thomson MO/TO | `Roms/THOMSON/`<br>`Roms/moto/`<br>`Roms/_etc/moto/` | `.fd`, `.sap`, `.k7`, `.m7`, `.m5`, `.rom` | **既定:** RA `theodore` |
| TI-83 | `Roms/TI83/`<br>`Roms/ti83/`<br>`Roms/_etc/ti83/` | `.8xp`, `.8xk`, `.8xg` | **既定:** RA `numero` |
| Uzebox | `Roms/UZEBOX/`<br>`Roms/uzebox/`<br>`Roms/_etc/uzebox/` | `.uze` | **既定:** RA `uzem` |
| Commodore VIC-20 | `Roms/VIC20/`<br>`Roms/vic20/`<br>`Roms/_etc/vic20/` | `.d64`, `.d6z`, `.d71`, `.d7z`, `.d80`, `.d81`, `.d82`, `.d8z`, `.g64`, `.g6z`, `.g41`, `.g4z`, `.x64`, `.x6z`, `.nib`, `.nbz`, `.d2m`, `.d4m`, `.t64`, `.tap`, `.tcrt`, `.prg`, `.p00`, `.crt`, `.bin`, `.cmd`, `.m3u`, `.vfl`, `.vsf`, `.zip`, `.7z`, `.gz`, `.20`, `.40`, `.60`, `.a0`, `.b0`, `.rom` | **既定:** RA `vice_xvic` |
| Dreamcast VMU | `Roms/VMU/`<br>`Roms/vmu/`<br>`Roms/_etc/vmu/` | `.vms`, `.dci`, `.bin` | **既定:** RA `vemulator` |
| Wolfenstein 3D | `Roms/WOLF3D/`<br>`Roms/wolf3d/` | `.wl6`, `.n3d`, `.sod`, `.sdm`, `.wl1`, `.pk3`, `.exe` | **既定:** RA `ecwolf` |
| ZX-81 | `Roms/ZXEIGHTYONE/`<br>`Roms/zx81/` | `.p`, `.tzx`, `.t81`, `.zip`, `.7z` | **既定:** RA `81` |
| ZX Spectrum | `Roms/ZXS/`<br>`Roms/zxspectrum/`<br>`Roms/_etc/zxspectrum/` | `.tzx`, `.tap`, `.z80`, `.rzx`, `.scl`, `.trd`, `.dsk`, `.dck`, `.sna`, `.szx`, `.zip`, `.gz`, `.udi`, `.mgt`, `.img`, `.7z` | **既定:** RA `fuse` |
| Arduboy | `Roms/ARDUBOY/`<br>`Roms/arduboy/` | `.hex` | **既定:** RA `arduous` |
| Mega Duck | `Roms/MEGADUCK/`<br>`Roms/megaduck/` | `.bin`, `.duck`, `.zip`, `.7z` | **既定:** RA `sameduck` |
| PuzzleScript | `Roms/PUZZLESCRIPT/`<br>`Roms/puzzlescript/` | `.pz`, `.pzp` | **既定:** RA `puzzlescript` |
| Super Bros War | `Roms/SUPERBROSWAR/`<br>`Roms/superbroswar/` | `.game` | **既定:** RA `km_superbroswar` |

## 現在無効なシステム

次の項目は内部カタログに残っていますが、Bubbleでは対応済みとして公開せず、
通常のTOP画面にも表示しません。3DSはRK3566の性能対象外のためカタログ自体から
除外しています。Java MEは実機検証で利用可能なゲームを確認できなかったため無効です。

| システム | 内部ID |
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

## 関連項目

- [エミュレータとゲーム中の操作](emulators.ja.md)
- [SDカードとフォルダ](storage.ja.md)
- [BIOS、セーブ、スクリーンショット](save-data.ja.md)

このファイルは`package/frontend-bubble/plumos/config/frontend/systems.json`を
正として、`scripts/generate-bubble-supported-systems-doc.py`で生成します。
