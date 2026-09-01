# Bubble external initramfs probe host validation

Date: 2026-09-02

Source commit: `cef1bdd`

## Gate

stock kernel、DTB、module ABIを維持したまま、外部initramfsがV90S由来のp1 System A/B、
p2 matching boot payload、p3 managed runtime境界を所有できるかを実機前に検証する。
このgateではpartition table、filesystem size、p4を変更しない。

## Provisional image geometry

| Region | Sector range | Size | Probe role |
| --- | ---: | ---: | --- |
| raw prefix | `0..32767` | 16 MiB | hash固定stock Rockchip boot prefix |
| p1 | `32768..1081343` | 512 MiB | FAT32 `PLUMBOOT`; kernel/initramfs/DTB + System A/B |
| p2 | `1081344..1212415` | 64 MiB | filesystemなしのraw newc matching bundle |
| p3 | `1212416..4358143` | 1536 MiB | ext4 `PLUMOS_SYS`; config、log、state |

p4は存在しない。これらの容量とp2 newc形式はone-shot probe専用であり、最終contractではない。
U-Bootは実証済みのp1 file bootを使い、p2 direct bootは次gateまで未証明とする。

## Stage contract

- U-Boot: `S10` entry、`S11` environment、`S12/E12` initramfs、`S13/E13` kernel、
  `S14/E14` DTB、`S15` overlay/fixup、`S19` handoff、`E20` return。
- external initramfs: `S21` entry、`S22` pseudo filesystem、`S23/E23` OS disk identity、
  `S24/E24` exact geometry、`S25/E25` p1/p3 authorization、`S26/E26` p2 raw full hash、
  `S27/E27` System A/B hash、`S28/E28` selected System mount、`S29/E29` switch root。
- minimal System: 既存の`S30..S39`、共通plumOS logo、AP6330、DHCP、Dropbearを継続する。

external initramfsの失敗はconsole/kmsgと、p3 mount後なら
`/plumos/logs/external-initramfs.log`へ保存する。`S29`以後はminimal Systemのrecovery SSHを使う。
`S29`より前の失敗は文字入力不能な実機ではSD readbackを回収経路とし、このgateでinitramfsへ
network stackを重複収録しない。

## Reproducible host result

```text
external_initramfs_size=2334157
external_initramfs_sha256=61be5dad14dacf3e9429a34a83854b417e07c63915d7dce1f3ed6d6dd1c3c288
minimal_system_size=8220672
minimal_system_sha256=4f9e3408b8cce9a5a21c5be802b2df47c20a2bf4feeb9dbec939f22977055afe
p2_raw_partition_sha256=042f5950539ce56fb8ba834fefd186582c19c9ea202f6aa7ea2cd84225e61acd
base_image_size=2231369728
base_image_sha256=7fff82670c8c36460cabe4a7d0472069fb7e605b88027f43c418a2b56a17f259
private_image_sha256=551819a71a11b7e509807bd0987e397ee81a074cb25f1e66e84da5bde0464dc2
```

同一commit/epochからbase imageを2回生成し、full image SHA-256が一致した。
独立verifierは次を確認した。

- MBRの3 partition exact sector geometryとp4不在。
- raw prefix、p1/p2/p3全領域SHA-256。
- p1 FATとp3 ext4のread-only fsck。
- p2がfilesystemを持たず`070701` newcで始まり、内部matching payloadの全checksumが合うこと。
- p1のSystem A/Bが同一のknown minimal Systemで、active slotが`a`であること。
- initramfsがAArch64 BusyBoxを持ち、`S21..S29/E23..E29`を含み、partition変更toolを呼ばないこと。
- private派生ではdevice-owned WPA configだけをp3へ追加し、byte readback、mode `0600`、
  ext4 cleanを確認した。credential内容と単独hashは記録していない。

build、base verify、private personalizationは次で再実行できる。

```sh
scripts/build-bubble-external-initramfs-probe-image.sh
scripts/verify-bubble-external-initramfs-probe-image.sh
scripts/personalize-bubble-external-initramfs-probe-wifi.sh \
  output/image/bubble-external-probe/plumOS-Bubble-0.1.0-dev-external-initramfs-probe.img \
  /absolute/private/path/wpa_supplicant.conf \
  output/image/bubble-external-probe/plumOS-Bubble-0.1.0-dev-external-initramfs-probe-wifi-private.img
```

## Physical gate

private派生イメージを新SDへfull write/readbackしてcold bootする。画面の共通plumOS logo、
`192.168.10.101`を第一候補とするARP/ping、SSH `root/plumos`を確認し、SSHから正常poweroffする。
SD readbackではp3の`external-initramfs.log`とminimal init log、p1/p2不変、p1 FAT/p3 ext4 cleanを
確認する。実機合格前にfirst-boot resizeやp4作成を有効化しない。

## First physical boot result

利用者がRaspberry Pi Imagerでprivate派生イメージを書き、Bubbleをcold bootした。
Macから既知のWi-Fi MAC `6c:21:a2:59:45:d6`を`192.168.10.101`で確認し、ping 3/3、
TCP 22、SSH `root/plumos`へ到達した。

実機のexternal initramfs persistent logは`S21`から`S29`まで、minimal System logは
`S30`から`S39`まで欠落なく記録し、`stage=E`は0件だった。主要readbackは次のとおり。

```text
root=/dev/loop0 squashfs ro
flash=/dev/mmcblk1p1 vfat ro
storage=/dev/mmcblk1p3 ext4 ro
p1=32768+1048576 sectors
p2=1081344+131072 sectors
p3=1212416+3145728 sectors
p4=absent
p2_sha256=042f5950539ce56fb8ba834fefd186582c19c9ea202f6aa7ea2cd84225e61acd
active_slot=a
system_a_sha256=4f9e3408b8cce9a5a21c5be802b2df47c20a2bf4feeb9dbec939f22977055afe
system_b_sha256=4f9e3408b8cce9a5a21c5be802b2df47c20a2bf4feeb9dbec939f22977055afe
wpa_state=COMPLETED
ip_address=192.168.10.101
```

kernel logにはpanic、Oops、call trace、filesystem I/O errorを検出しなかった。SSHから
`sync; poweroff`を実行し、2回目のpollでping unreachable、TCP 22 closedを確認した。
poweroff後のoffline p1/p2 hashとFAT/ext4 fsckは、SDをMacへ接続してから実施する。
