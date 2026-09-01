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

- U-Boot environment の保存場所、fallback、SD 選択規則
- built-in initramfs内のexact init/pivot処理

### macOS raw prefix capture

OS SDをmacOSへ接続し、`/dev/disk4`が次と一致することを確認してから全volumeをunmountし、
`/dev/rdisk4`の先頭16 MiBだけを読み取った。SDへのwriteは実行していない。

| 項目 | 観測値 |
| --- | --- |
| physical size | 124,383,133,696 bytes / 242,935,808 sectors |
| sector size | 512 bytes |
| partition table | MBR |
| p1 start | sector 32768 / 16,777,216 bytes |
| p1 | FAT32 `EMUELEC`, 5,967,233 sectors |
| p2 | Linux type 0x83, 236,935,168 sectors |
| captured prefix | exactly 16,777,216 bytes |
| prefix SHA-256 | `648078e91860adf21bd4ec8f1fd8a64ce52de0ce24511393b156b920327b4ec2` |

prefixはMBRだけではない。offset `0x8000`に`RKNS` loader、`0x100000`と`0x800000`に
FIT header、`0xc00000`に`BL3X` headerがあり、RK3566 DDR初期化、U-Boot SPL 2017.09、
ATF/U-Boot文字列を確認した。したがって16 MiB全体をexact immutable vendor inputとして扱い、
個別領域へ分解して再配置する前に複製SDでboot equivalenceを証明する。

prefix内のU-Boot default文字列には`boot_targets=mmc1 mmc0 usb0 pxe dhcp`、
`bootcmd=run distro_bootcmd`、`boot.scr.uimg`/`boot.scr`探索が含まれる。これは現行の
FAT p1 file bootと整合するが、保存済みactive environmentを読んだ結果ではない。
したがってV90S型raw p2 bootへ切り替える前に、複製SDでactive selectionとfallbackを証明する。

runtime cmdlineは`initrd=`が空で、kernel configは`CONFIG_INITRAMFS_SOURCE`にvendor build host上の
`emuelec-init`構成を指定している。このため外部initrdではなく、kernelへ組み込まれたinitramfsが
ext4 p2を初期rootとして処理し、p1 `SYSTEM`をloop/SquashFS rootへhandoffしていると判断できる。
起動後はp1が`/flash` read-only、p2が`/storage` read-write、`SYSTEM` loopが`/` read-onlyである。
exact init/pivot scriptはまだ抽出できていない。

FAT p1はread-only mountしてhashを取得した。active boot inputのexpected hashは
`configs/bubble-stock-active-boot.expected.sha256`に記録した。p1にはuser-owned ROM fileも
存在するため、boot artifact captureでは明示したkernel/DTB/scriptだけを対象にし、ROM treeを
コピーまたはhash inventoryへ含めない。

### Runtime DTB と kernel ABI

起動後の`/sys/firmware/fdt`をexact 147,584 bytesで採取した。SHA-256は
`5ea527f8ab546914f1aecd4cc5674e1ac4243847b18badce68aaa89d8f9e72ac`である。
`scripts/compare-fdt.py`でselected base DTBとproperty単位に比較したところ、base 4,225、
runtime 4,230 propertiesのうち差分は6件だけだった。

- bootloaderが追加するserial number、`/chosen/bootargs`、memory type/ranges
- boot logo用reserved-memoryの実address/size
- `/reserved-memory/rknpu:status = "disabled"`

最後の差分は選択済み`rk3568-disable-npu` overlayと一致する。その他に予期しないnode/propertyの
変更はなく、runtime treeはselected base DTBへboot時情報と選択overlayを反映したものと判断できる。

kernelは`4.19.193-g5a07852a55cf-dirty`で、`/proc/config.gz`は33,182 bytes、SHA-256
`451239de032024550908580f81f361eb68d21a604f54a13c30b028c41ff437c3`だった。
module treeは`/usr/lib/kernel-overlays/base/lib/modules/<kernel>`にあり、556 files、
合計23,745,072 bytesをpath/size/SHA-256で一覧化した。firmware treeも322 files、
合計32,153,018 bytesを同様に一覧化した。inventory自体のSHA-256はそれぞれ
`c8b5c18c8e220eee26c5bafe05d79a5ae31a1940d5df6031de36b10acaeb39b0`、
`cd146030322fbd0b2fb568bcdbf3a17823f33bf29913a0953dd8c0379dc6deb4`である。

起動中に必要性を確認した固定ABI候補は次の通りである。

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| `bcmdhd.ko` | 3,625,144 | `fd8abaada4aed3ef140e778e344316a1727b0c8d7d9d83d0aee51e3d008297f4` |
| `dwc3.ko` | 119,368 | `e7e8bc20098908c67d9c521285addc352d42b1c5d4c18c0233a7529af224df9f` |
| `udc-core.ko` | 43,872 | `7f0cf5782bc2340b8000373bcffcf3799505df3ee5c53e13182530d745246b68` |
| `dwc3-of-simple.ko` | 16,240 | `1148a5d7ba40168cb70b5b7b7614739143a4d84c4b9ea483b44fb3c2120e0005` |
| `fw_bcm43438a1.bin` | 414,579 | `c587abd06865aab98290e1bdd1e9185cfb5c30f89af329c77e0202afe4b932c1` |
| `nvram_AP6330.txt` | 1,522 | `68952ca377ea4f629c7d01042ba6d95e2c74f347a893c4d49a4d3c3f38a5bf1b` |
| AArch64 `libmali.so.1.9.0` | 43,489,296 | `56e37253ef3c217932aa947734399203614dfa6046a077444d4c76fd29ea5be2` |
| ARMhf `libmali.so.1.9.0` | 42,431,936 | `bbe45b17ec872897a0039a685ba25e87ea8fa2244f3a36648c37acf9fdb55d34` |

`bcmdhd.ko`のvermagicはkernel releaseと一致し、実際のWi-Fi firmwareはboot log上
`fw_bcm43438a1.bin`だった。vendor Maliは64-bit/32-bit双方が存在し、root userspaceは
glibc 2.38である。これらのcaptureは解析専用で、source identity、license、再配布権を
確認するまでplumOS image/releaseへ含めない。expected hashは
`configs/bubble-stock-runtime.expected.sha256`に記録した。

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

process/fd readbackではEmulationStationが`event0..3`も直接openしていた。別processの
`input_sense`は`evtest`を`event0..2`へ接続しており、stock環境はfrontendとsystem helperが
同じinput sourceを並行監視する構成である。plumOSではこの構成をそのままコピーせず、
hotkey/power監視とfrontend/game inputの所有境界を一つに定める必要がある。

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

storage/update ownershipはV90S由来のp1 `PLUMBOOT`、p2 `BOOT`、p3 `PLUMOS_SYS`、
p4 `PLUMOS`とoptional SD2を採用する。boot implementationは、raw Rockchip prefix、U-Boot、
vendor kernel、exact DTB と必要な firmware/module をhardware substrateとして保持し、
`SYSTEM`以降をplumOSが所有する方式を候補とする。p2形式と各容量は、複製SDでDTB、
initrd/handoff、rollbackを実証した後に固定する。

MF は同じ RK3566/RK817/640x480 の hardware probe 参考、Pixel2 は stock substrate と
System ownership の参考、V90S/XU20 は vendor artifact 固定と transactional update の参考にする。
各機種固有の path、button code、DTB、GPU library、partition number はコピーしない。
