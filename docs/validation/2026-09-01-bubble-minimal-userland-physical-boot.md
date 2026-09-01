# Bubble minimal userland physical boot validation

Date: 2026-09-01  
Image source commit: `b0110c9`  
Image SHA-256: `730db733fe883a5fabc2176d447d57feb97bd651e22efa2dd8232374e5903a4c`

## Result

新SDへ書いたone-slot bring-up imageをGKD Bubbleでcold bootし、液晶のplumOS marker後に
BusyBox promptへ到達した。電源OFF後、Macへ戻したSDを`/dev/disk4`、62.5 GB、
`PLUMBOOT` FAT32 512 MiB + `PLUMOS_SYS` ext4 1.6 GBとして再同定した。

FATの最終system markerは次だった。

```text
S39_RECOVERY_IDLE_STORAGE_RO
```

p2 readbackは次の読み取り専用コマンドで採取した。

```sh
sudo dd if=/dev/rdisk4s2 \
  of=work/bubble-boot-readback/storage-after-first-boot.ext4 bs=4m
```

```text
size=1593835520
sha256=add03410817d4ec9e02807d00dfcf99a063098070cc54f0a32eb9e58e834d9a5
filesystem_label=PLUMOS_SYS
filesystem_uuid=42554242-4c45-5359-5300-000000000002
filesystem_state=clean
mount_count=1
```

`e2fsck -fn`はエラーなしで完了した。persistent logには全stageが順番に残った。

```text
plumos-bubble-init=stage=S30_SYSTEM_ENTRY
plumos-bubble-init=stage=S31_STORAGE_MOUNTED
plumos-bubble-init=stage=S32_FLASH_MOUNTED
plumos-bubble-init=stage=S33_FRAMEBUFFER_MARKER_DRAWN
plumos-bubble-init=stage=S39_RECOVERY_IDLE_STORAGE_RO
```

## Proven runtime boundary

- kernel cmdlineはseed UUIDと`plumos_seed=1`を受け取った。
- stock built-in initramfsは`/dev/mmcblk1p1`を`/flash`、SYSTEM loopを`/`、
  `/dev/mmcblk1p2`を`/storage`としてmountした。
- kernelは640x480p60 DRM、`fb0`、DRM card/render node、`event0..3`、
  RK817 audio、AP6330 SDIO、Mali、`retrogame_joypad`をprobeした。
- OS SDは`/dev/mmcblk1`、もう一方のカードは`/dev/mmcblk3p1`として列挙された。
- stock frontendは開始せず、plumOS-owned `/init`がBusyBox recovery promptを保持した。

これによりBoot ROM/loader/U-Boot/kernel/stock built-in initramfsから新規plumOS `SYSTEM`への
handoff、p1/p2 ownership、fbdev表示、persistent loggingの最小経路は実機で成立した。

## Unresolved

`plumos-probe/uboot-stage.txt`は初期値`----`のままだった。boot成功からinstrumented
`boot.scr`自体は実行されたと判断できるが、stock U-Bootの`fatwrite`成功は証明できない。
次seedではU-Boot FAT markerを必須証拠にせず、kernel cmdlineとearly-init snapshotへ
boot source、root identity、直前handoff情報を残す。

Wi-Fi、Dropbear recovery SSH、normal shutdown、warm reboot、frontendはこの試験範囲外である。
