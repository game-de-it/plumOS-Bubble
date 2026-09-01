# Bubble boot probe

このprobeは「boot失敗」を一つの状態として扱わず、最後に完了したstageを新しい検証用SDへ残す。
original OS SDでは実行しない。

## Log channels

| Channel | 到達前提 | 保存先 | 回収方法 |
| --- | --- | --- | --- |
| U-Boot console | boot script実行 | serial `ttyFIQ0` | UART capture |
| U-Boot FAT marker | p1 FAT read/write | `plumos-probe/uboot-stage.txt` | SDをMacへ戻す |
| system persistent log | built-in initramfsがp2をmountしsystemd開始 | `/storage/plumos/boot-probe/logs/<boot-id>.log` | SSHまたはLinuxでext4 mount |
| system FAT mirror | systemd probe実行 | `plumos-probe/system-stage.txt` | SDをMacへ戻す |
| runtime snapshot | systemd + `/storage` writable | `<boot-id>.snapshot.txt` | SSH |

U-BootとsystemdのFAT書込みはprobe cloneだけで行う。systemd側はmarkerをatomic renameし、
`sync`後すぐ`/flash`をread-onlyへ戻す。original SDにはclone authorization markerがないため、
prepare/install scriptは拒否する。

## Stage map

| Stage | 意味 |
| --- | --- |
| `S10` | U-Bootがinstrumented `boot.scr`へ入った |
| `S11` | `uEnv.txt` importを完了した |
| `S12` / `E12` | kernel `Image` load成功 / 失敗 |
| `S13` / `E13` | selected DTB load成功 / 失敗 |
| `S14` | overlay/fixup処理を完了した |
| `S19` | `booti`呼出し直前 |
| `E20` | `booti`が戻った。kernel handoff失敗 |
| `S30` | stock built-in initramfsがplumOS `SYSTEM` entrypointを実行した |
| `S31` / `E31` | p2 ext4 `/storage` mount成功 / 失敗 |
| `S32` / `E32` | p1 FAT `/flash` mount成功 / 失敗 |
| `S33` / `E33` | framebuffer marker描画成功 / fbdev利用不可 |
| `S34` / `E34` | hash固定bcmdhd moduleが既にactiveまたはload成功 / load失敗 |
| `S35` / `E35` | `wlan0`出現・link up / interface未出現 |
| `S36` / `E36` | device-owned WPA configからsupplicant開始 / config不在または開始失敗 |
| `S37` / `E37` | APへassociation完了 / bounded timeout |
| `S38` / `E38` | DHCP address取得とDropbear開始 / DHCP・host key・listener失敗 |
| `S39` / `E39` | 最小recovery待機へ到達しp2をread-only化 / read-only化失敗 |
| `S40` | built-in initramfsと`SYSTEM` handoff後、systemd probeへ到達 |
| `S45` | `/storage` persistent logへ書込み成功 |
| `S60` | mount、hash、systemd、network、dmesg snapshot保存完了 |
| `S70` | stock frontendの`ExecStart`直前 |
| `S80` / `E80` | frontend process開始 / unit失敗 |
| `S90` | frontend開始を含む`miniplus.target` boot完了 |

初回physical seed bootではsystem側`S30..S39`とBusyBox promptまで到達したが、U-Boot
`fatwrite` markerは初期値`----`のままだった。したがってstock U-BootのFAT書込みは
診断の必須条件にしない。次seed以降はkernel cmdline、early-init snapshot、必要ならUARTを
U-Bootからkernelへの境界証拠として併用する。

`uboot-stage.txt=S19`でsystem logが無い場合、kernel entryからbuilt-in initramfs、p2 mount、
`SYSTEM` loop handoffの間に失敗している。`S40`以降はboot ID単位のsnapshotでさらに切り分ける。

## Build verification

`scripts/mkimage-uboot-script.py`はhostの`mkimage`へ依存せずlegacy script imageを生成する。
stock `boot.cmd`と元header timestampを入力した場合、stock `boot.scr`とbyte-identicalになることを
test gateとする。instrumentationはknown stock `boot.cmd` SHA-256以外を拒否する。

```sh
python3 scripts/instrument-bubble-boot-script.py \
  artifacts/vendor/bubble-stock-source/boot/boot.cmd \
  work/bubble-boot-probe
```

## Preferred one-slot deployment order

1. stock OS稼働中にraw 16 MiBとactive boot matching setをSSHからread-only captureする。
2. clean arm64 containerで最小plumOS `SYSTEM`と2 GiB seed imageを生成・検証する。
3. original OS SDを実機から抜いて保管する。
4. 新SDだけをMacへ挿し、seed imageを書いて全image-size blockをreadbackする。
5. 新SDを実機でcold bootし、画面の`S33` markerを確認する。
6. 失敗時はSDをMacへ戻し、FATの`uboot-stage.txt`と`system-stage.txt`を読む。
7. `S33`合格後にWi-Fi/SSHとfrontendをminimal Systemへ一層ずつ追加する。

build/verify:

```sh
scripts/build-bubble-seed-image.sh
scripts/verify-bubble-seed-image.sh
```

Wi-Fi credentialは共通imageへ入れない。通常形式の`wpa_supplicant.conf`をrepository外に作り、
`ctrl_interface=/run/wpa_supplicant`を含める。次のpersonalizationはbase imageを変更せず、
別imageのp2 `/plumos/config/wpa_supplicant.conf`へmode 0600で書く。生成したpersonalized imageは
credentialを含むため公開しない。

```sh
scripts/personalize-bubble-seed-wifi.sh \
  output/image/bubble/plumOS-Bubble-0.1.0-dev-seed.img \
  /absolute/private/path/wpa_supplicant.conf \
  output/image/bubble/plumOS-Bubble-0.1.0-dev-seed-wifi.img
```

recovery SSHはTCP 22、user/passwordはdevelopment既定の`root` / `plumos`である。
host keyはp2 `/plumos/ssh`へ初回生成し、System rebuildでは上書きしない。

新SDへのwriteはwhole-disk identifier確定後にだけ行う。

```sh
PLUMOS_BUBBLE_WRITE_TARGET=/dev/diskN \
  scripts/write-bubble-seed-image-macos.sh \
  output/image/bubble/plumOS-Bubble-0.1.0-dev-seed.img /dev/diskN
```

## Optional exact-clone route

2つのSD readerを使用できる場合は、既存のdevice-to-device clone probeも引き続き利用できる。
これはstock CFW equivalence確認用であり、one-slot最小plumOS bring-upの必須工程ではない。

system probe installは再起動しない。clone確認後に実行する例:

```sh
PLUMOS_BUBBLE_SSH_PASSWORD=plumos \
  scripts/install-bubble-system-boot-probe-over-ssh.sh
```

rollbackはprobe cloneを抜きoriginal OS SDへ戻す。clone p1内のstock `boot.cmd`と`boot.scr`は
`plumos-probe/original/`にも保持する。

cloneはsourceとtargetのwhole-disk identifierを目視確認してから、target identifierを環境変数にも
完全一致で指定する。scriptはinternal/non-removable disk、既知source size・prefix不一致、
target容量不足を拒否する。次は例であり、実際のidentifierを`diskutil list external physical`で
確定してから置き換える。

```sh
PLUMOS_BUBBLE_CLONE_TARGET=/dev/diskTARGET \
  scripts/clone-bubble-stock-sd-macos.sh /dev/diskSOURCE /dev/diskTARGET
```
