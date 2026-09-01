# GKD Bubble 初回読み取り専用インベントリ

採取日: 2026-09-01  
対象: `root@192.168.10.101` で起動中の stockOS ベース CFW  
方法: SSH から `/proc`、`/sys`、mount、block metadata、boot files、process のみを読み取った。

この調査では、実機ファイルの作成・更新・削除、service 操作、mount 変更、再起動、
block device の書き込みを行っていない。

## 確認済み事実

### SoC、kernel、device identity

| 項目 | 観測値 |
| --- | --- |
| hostname | `bubble` |
| machine model | `GameKiddy GKD Geek` |
| DT compatible | `GameKiddy,gkd-geek`, `rockchip,rk3566` |
| architecture | AArch64、Cortex-A55 x4 |
| memory | 約 1 GiB (`MemTotal: 990704 kB`) |
| kernel | `4.19.193-g5a07852a55cf-dirty`、vendor build |
| CFW identity | `MINIPLUS` / `BBG v5.3 2024-10-15` |
| init | `/usr/lib/systemd/systemd` |

kernel source は手元にないが、実機の `/proc/config.gz` は読み取り可能である。
vendor kernel は Rockchip DRM/VOP2、DSI、RK817、RGA2、MPP、proprietary Mali Bifrost、
evdev/uinput、overlayfs、SquashFS を含む。

### SD と runtime layout

OS 側 SD は実機上で `/dev/mmcblk1`、ROM 側 SD は `/dev/mmcblk3` として見えている。
番号は挿入条件で変わり得るため、実装では固定しない。

| Device | Layout | 現在の mount |
| --- | --- | --- |
| `/dev/mmcblk1` | MBR、約 116 GiB | OS SD |
| `/dev/mmcblk1p1` | FAT32、約 2.9 GiB、label `EMUELEC`、LBA 32768 start | `/flash`、read-only |
| `/dev/mmcblk1p2` | ext4、約 113 GiB | `/storage`、read-write |
| `/dev/mmcblk3p1` | FAT32、約 58.2 GiB、label `GAME` | `/storage/roms`、read-only |
| `/flash/SYSTEM` | SquashFS、2,038,734,848 bytes | loop device `/dev/loop0` から `/`、read-only |

`/storage` には active configuration、SSH key、frontend、core、Pyxel、save 相当の
mutable data が存在する。plumOS の build/deploy metadata に合わせる目的で、これらを
上書きしてはならない。

ROM SD は boot log で dirty volume と報告されている。現段階では修復していない。
修復が必要な場合は、利用者の許可を得て退避または複製後に別作業として扱う。

### 現在見える boot files

`/flash` で次を確認した。

| File | Size / identity |
| --- | --- |
| `Image` | 18,935,816 bytes、SHA-256 `a6674c54976bf1bea36891bdb7f7a17c6f895437973adbda78fa7556570bfaab` |
| `SYSTEM` | 2,038,734,848 bytes、SquashFS |
| `boot.cmd` | U-Boot script source |
| `boot.scr` | compiled U-Boot script |
| `uEnv.txt` | Bubble boot parameters |
| `dtbs/4.19.193-51-rockchip-gb2c01b3d79f2/` | kernel DTB tree |

`uEnv.txt` は次を選択する。

- normal DTB: `rockchip/rk3566-gkd-geek-bbg.dtb`
- HDMI DTB: `rockchip/rk3566-gkd-geek-bbg-hdmi.dtb`
- overlays: `rk3568-fiq-debugger-uart2m0`, `rk3568-disable-npu`
- kernel: `Image`
- root UUID: 現 OS SD の ext4 partition UUID

`boot.cmd` は kernel、DTB、overlay、initrd 変数を U-Boot 環境から組み立て、`booti` する。
ただし次はまだ未確認である。

- SD 先頭 16 MiB にある Rockchip IDBLoader/U-Boot の正確な配置と hash
- U-Boot environment の保存場所、fallback、SD 選択規則
- `initrdimg` / `initrdsize` の実値と初期 userspace handoff
- runtime に適用済みの exact DTB と `/flash` 上 DTB の一致

### Display と GPU

| 項目 | 観測値 |
| --- | --- |
| DRM | `rockchip-drm`, `/dev/dri/card0`, `/dev/dri/renderD128` |
| connector | `DSI-1`, connected |
| mode | `640x480`; boot log は `640x480p60` |
| fbdev | `/dev/fb0`, 640x480, 32 bpp, stride 2560 |
| GPU | `/dev/mali0`, Bifrost GPU arch 7.4.0 r1p0 |
| userspace | vendor `libmali.so.1.9.0`, EGL/GLES symlink が同 library を指す |

起動中の EmulationStation は `/dev/dri/card0` と `/dev/mali0` を開き、vendor Mali、SDL2、
libdrm、PipeWire/PulseAudio を map している。したがって GPU userspace は kernel ABI と
組で扱う必要がある。plumOS の初期 bring-up は software DRM/KMS path を先に通し、
vendor GPU を採用するかはライセンス・再配布・ABI・性能を別 gate で決める。

### Input

| Event | Device | 確認できた用途 |
| --- | --- | --- |
| `event0` | `rk805 pwrkey` | power key |
| `event1` | `gpio-keys` | GPIO key。物理対応は未採取 |
| `event2`, `js0` | `retrogame_joypad` | ABXY/D-pad/shoulder/analog 等の候補 |
| `event3`, `js5` | `gsensor` | 3-axis sensor |

`retrogame_joypad` は vendor/product `484b:1101`、force feedback と analog axis を公開する。
物理ボタンと event code の対応、press/release、同時押し、rumble、hotkey はまだ未確認であり、
対話式実機採取なしに他機種の mapping を流用してはならない。

### Audio、power、network

| 領域 | 観測値 |
| --- | --- |
| audio | card 0 `rockchip,rk817-codec`, I2S playback/capture |
| current audio service | PipeWire + WirePlumber + PipeWire Pulse |
| backlight | `/sys/class/backlight/backlight`, 0..255、現在 10 |
| battery | RK817 battery、capacity/status/voltage/current を sysfs で取得可能 |
| charger | AC/USB 系 power-supply nodes が複数存在 |
| internal Wi-Fi | AP6330、SDIO、vendor `bcmdhd`, interface `wlan0` |
| current network | wpa_supplicant + ConnMan、SSH は TCP 22 |

speaker/headphone route、実 sample rate、safe volume range、jack detection、shutdown、
charger-connected boot、suspend/resume は物理操作を伴うため未確認である。

## 暫定結論

最初の plumOS architecture 候補は、raw Rockchip boot prefix、U-Boot、vendor kernel、
exact DTB と必要な firmware/module を hardware substrate として保持し、`SYSTEM` 以降を
plumOS が所有する方式である。ただしこれは採用決定ではない。複製 OS SD から boot prefix、
DTB、initrd/handoff を再現可能に採取し、rollback を実証した後に決定する。

MF は同じ RK3566/RK817/640x480 の hardware probe 参考、Pixel2 は stock substrate と
System ownership の参考、V90S/XU20 は vendor artifact 固定と transactional update の参考にする。
各機種固有の path、button code、DTB、GPU library、partition number はコピーしない。

