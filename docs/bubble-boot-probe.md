# Bubble clone boot probe

このprobeは「boot失敗」を一つの状態として扱わず、最後に完了したstageをclone SDへ残す。
original OS SDでは実行せず、全block readback済みcloneだけで使う。

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
| `S40` | built-in initramfsと`SYSTEM` handoff後、systemd probeへ到達 |
| `S45` | `/storage` persistent logへ書込み成功 |
| `S60` | mount、hash、systemd、network、dmesg snapshot保存完了 |
| `S70` | stock frontendの`ExecStart`直前 |
| `S80` / `E80` | frontend process開始 / unit失敗 |
| `S90` | frontend開始を含む`miniplus.target` boot完了 |

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

## Deployment order

1. original OS SDをoffline sourceとして別SDへdevice-to-device cloneする。
2. source size分をtargetから全block readbackし、sourceと一致させる。
3. clone scriptがtarget p1へ`PLUMOS_BUBBLE_CLONE_PROBE_V1 <disk id>` markerを作る。
4. `prepare-bubble-clone-boot-probe-macos.sh /Volumes/<clone p1>`を実行する。
5. cloneを実機でcold bootし、FAT `uboot-stage.txt`とstock hardware/SSHを確認する。
6. clone起動中にsystem-stage probeをSSH installする。
7. reboot後、`latest-stage`、boot ID log、snapshot、FAT mirrorをreadbackする。

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
