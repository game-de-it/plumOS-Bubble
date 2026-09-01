# Bubble boot probe

このprobeは「boot失敗」を一つの状態として扱わず、最後に完了したstageを新しい検証用SDへ残す。
original OS SDでは実行しない。

## Log channels

| Channel | 到達前提 | 保存先 | 回収方法 |
| --- | --- | --- | --- |
| U-Boot console | boot script実行 | serial `ttyFIQ0` | UART capture |
| system persistent log | built-in initramfsがp2をmountしsystemd開始 | `/storage/plumos/boot-probe/logs/<boot-id>.log` | SSHまたはLinuxでext4 mount |
| system FAT mirror | systemd probe実行 | `plumos-probe/system-stage.txt` | SDをMacへ戻す |
| runtime snapshot | systemd + `/storage` writable | `<boot-id>.snapshot.txt` | SSH |

systemd側のFAT書込みはprobe cloneだけで行う。markerをatomic renameし、
`sync`後すぐ`/flash`をread-onlyへ戻す。original SDにはclone authorization markerがないため、
prepare/install scriptは拒否する。

stock U-Bootの`fatwrite`はactive directory entryを更新せず`S19\n`の孤立clusterを残し、
macOSのFAT checkが`FSCK0000.000`として回収した。そのためU-Boot stageはconsole/UARTへの
`echo`だけとし、FATをU-Bootから書き換えない。

## Stage map

| Stage | 意味 |
| --- | --- |
| `S10` | U-Bootがinstrumented `boot.scr`へ入った |
| `S11` | `uEnv.txt` importを完了した |
| `S12` / `E12` | 2 partition seedではkernel、external probeではinitramfsのload成功 / 失敗 |
| `S13` / `E13` | 2 partition seedではselected DTB、external probeではkernelのload成功 / 失敗 |
| `S14` / `E14` | 2 partition seedではoverlay完了、external probeではselected DTBのload成功 / 失敗 |
| `S15` | external probeのoverlay/fixup処理を完了した |
| `S19` | `booti`呼出し直前 |
| `E20` | `booti`が戻った。kernel handoff失敗 |
| `S21` | external initramfs entryへ到達 |
| `S22` | proc/sys/dev/run/tmpを準備し、共通plumOS logoを描画 |
| `S23` / `E23` | `PLUMBOOT`からOS SDとp1/p2/p3を解決 / identity不一致 |
| `S24` / `E24` | one-shot用exact geometryとp4不在を確認 / geometry不一致 |
| `S25` / `E25` | p1 read-only、p3 read-writeでauthorization確認 / mountまたはmarker不一致 |
| `S26` / `E26` | p2 raw partition全体のSHAとnewc magic確認 / matching bundle不一致 |
| `S27` / `E27` | System A/Bとactive slotのSHA確認 / slot metadata不一致 |
| `S28` / `E28` | selected Systemをread-only loop mount / System contract不一致 |
| `S29` / `E29` | p1を`/flash`、p3を`/storage`へ移動してswitch root / handoff失敗 |
| `S30` | stock built-in initramfsがplumOS `SYSTEM` entrypointを実行した |
| `S31` / `E31` | p2 ext4 `/storage` mount成功 / 失敗 |
| `S32` / `E32` | p1 FAT `/flash` mount成功 / 失敗 |
| `S33` / `E33` | 既存plumOS共通logoをframebufferへ描画成功 / fbdev利用不可 |
| `S34` / `E34` | hash固定bcmdhd moduleが既にactiveまたはload成功 / load失敗 |
| `S35` / `E35` | `wlan0`出現・link up / interface未出現またはfirmware loadを伴うlink up失敗 |
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

初回physical seed bootではsystem側`S30..S39`とBusyBox promptまで到達した。U-Bootから
kernelへの境界証拠はkernel cmdline、early-init snapshot、必要ならUARTを併用する。

system logが無い場合、kernel entryからbuilt-in initramfs、p2 mount、`SYSTEM` loop handoffの
間はUARTで切り分ける。`S40`以降はboot ID単位のsnapshotでさらに切り分ける。

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
5. 新SDを実機でcold bootし、既存plumOS共通logoとFATの`S33` markerを確認する。
6. 失敗時はSDをMacへ戻し、FATの`system-stage.txt`とp2 persistent logを読む。
7. `S33`合格後にWi-Fi/SSHとfrontendをminimal Systemへ一層ずつ追加する。

build/verify:

```sh
scripts/build-bubble-seed-image.sh
scripts/verify-bubble-seed-image.sh
```

external initramfsのread-only boundary probeは次でbuild/verifyする。これは3 partitionだが、
p2 direct boot、first-boot expansion、p4作成をまだ含まない。external initramfsは
`/storage/plumos/logs/external-initramfs.log`へstageを残し、`S29`後は既存minimal Systemの
Wi-Fi/SSH recoveryへ引き渡す。

```sh
scripts/build-bubble-external-initramfs-probe-image.sh
scripts/verify-bubble-external-initramfs-probe-image.sh
```

実機用credentialはbaseを変更せずprivate派生のp3へだけ注入する。

```sh
scripts/personalize-bubble-external-initramfs-probe-wifi.sh \
  output/image/bubble-external-probe/plumOS-Bubble-0.1.0-dev-external-initramfs-probe.img \
  /absolute/private/path/wpa_supplicant.conf \
  output/image/bubble-external-probe/plumOS-Bubble-0.1.0-dev-external-initramfs-probe-wifi-private.img
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
DHCP成功時のaddressはFAT `plumos-probe/network-address.txt`にも原子的に記録する。

新SDへのwriteはwhole-disk identifier確定後にだけ行う。
Mac内蔵SDXC readerは`Internal=true`と報告されるため、writerは`disk0`を常に拒否し、
internal targetの場合はSecure Digital、removable、ejectable、physical、writableの全条件を要求する。
`PLUMOS_BUBBLE_VALIDATE_ONLY=1`でunmount/writeなしのtarget gateだけを先に実行できる。

```sh
PLUMOS_BUBBLE_WRITE_TARGET=/dev/diskN \
  scripts/write-bubble-seed-image-macos.sh \
  output/image/bubble/plumOS-Bubble-0.1.0-dev-seed.img /dev/diskN
```

## Optional exact-clone route

2つのSD readerを使用できる場合は、既存のdevice-to-device clone probeも引き続き利用できる。
これはstock CFW equivalence確認用であり、one-slot最小plumOS bring-upの必須工程ではない。

## Diagnostic-only boundary

この2 partition seedはboot handoffとhardware recoveryを調べるためだけの非release artifactである。
first-boot partition expansion、System A/B、p3 runtime、p4 user/update領域を持たず、正式imageの
storage/update ABIとして扱わない。manifestの`final_partition_contract=no`、
`first_boot_provisioning=not-included`、`publishable=no`をverifierで必須確認し、release対象にしない。

画面デザインはBubble独自にしない。V90S、A30、MFで共通の640x480 plumOS logoをexact hashで
再利用し、Bubble固有処理は実機`fb0`向けXRGB8888変換だけに限定する。

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
