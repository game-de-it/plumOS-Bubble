# Bubble recovery-network seed host validation

Date: 2026-09-01; latest corrective build 2026-09-02
Source commit: `ed9549b`

Scope: host build、private personalization、2回のphysical失敗解析、3回目physical合格。
latest corrective buildのWi-Fi/DHCP/SSHは実機確認済み。

## Recovery System

初回physical handoffに合格した最小SYSTEMへ、次の一層だけを追加した。

- stock kernelとvermagicが一致するhash固定`bcmdhd.ko`
- stock boot logで使用を確認したAP6330 firmwareとNVRAM
- Debian Bookworm arm64 `wpa_supplicant`とruntime libraries
- Debian Bookworm arm64 Dropbear、persistent host key、development password login
- bounded module/interface/association/DHCP/SSH stages `S34..S38` / `E34..E38`
- network後のcmdline、mount、address、device、process、kernel snapshot
- driver自動選択名を含むhash固定firmware/NVRAM配置
- V90S/A30/MFと同一のplumOS共通640x480 boot visual

SYSTEM result:

```text
size=8220672
sha256=49514b6454e84f0e2efdbdcb549df64bd416c1b83e1de76516dad7e6ddb09bc2
kernel_release=4.19.193-g5a07852a55cf-dirty
bcmdhd_sha256=fd8abaada4aed3ef140e778e344316a1727b0c8d7d9d83d0aee51e3d008297f4
wifi_firmware_sha256=c587abd06865aab98290e1bdd1e9185cfb5c30f89af329c77e0202afe4b932c1
wifi_nvram_sha256=68952ca377ea4f629c7d01042ba6d95e2c74f347a893c4d49a4d3c3f38a5bf1b
```

rootfs内chrootでWPAとDropbearのversion実行、dynamic loader/library解決、shadow mode 0600、
vendor artifact SHA、module vermagic、SquashFS必須pathを確認した。network daemonのlog fdは
tmpfs `/run`へ保持し、startup logをp2へcopyしてからp2をread-onlyへ戻す。

## Base image

先行sourceでは同じcommitから完全imageを2回生成し、image本体とmanifestのbyte-identical一致を
確認した。latest corrective source `ed9549b`では次のimageを生成し、独立verifierに合格した。

```text
file=output/image/bubble/plumOS-Bubble-0.1.0-dev-seed.img
size=2147483648
sha256=95ad78206683f50580d3a4071b7b8c75b8dc46ad2be2b7f834316532b2fc2095
boot_filesystem_sha256=c718daba36c34aa428adffa90e30042df145a0afa4ac788ec593429b723e67d2
sys_filesystem_sha256=c0ee12e6171e7afbdfeba59ea3cdb221ea62c316ce9e259f12079f7669e33992
```

independent verifierはRockchip prefix、MBR、FAT/ext4、SYSTEM readback、root UUID、seed markerを
確認した。FATの`plumos-probe/network-address.txt`は生成時に`NOT_ASSIGNED`で初期化し、起動時に
DHCP addressをatomic renameで記録する。共通imageとrepositoryにはSSID、PSK、平文passwordを
含めていない。p1/p2の2 partition構成はboot-boundary診断専用で、manifestに
`final_partition_contract=no`、`first_boot_provisioning=not-included`、`publishable=no`を持つ。

## Private personalization

利用者指定WLAN credentialをrepository外でWPA-PSKへ変換し、base imageを変更せず、別imageの
p2 `/plumos/config/wpa_supplicant.conf`へmode 0600で注入した。credential内容と単独hashは
manifestへ記録しない。

```text
file=output/image/bubble/plumOS-Bubble-0.1.0-dev-seed-wifi.img
size=2147483648
sha256=6074e7f54bba8281a922833d28fe94a19514c6c271504e3c9b4cb339130efa55
base_image_sha256=95ad78206683f50580d3a4071b7b8c75b8dc46ad2be2b7f834316532b2fc2095
publishable=no
```

personalized p2を再抽出し、`e2fsck -fn` clean、config byte一致、mode 0600、full image checksum、
平文password非混入を確認した。このimageはprivate physical bring-up専用で公開しない。

## First physical network boot

source `6630283`のpersonalized seedをcold bootした結果、FATは`S39_RECOVERY_IDLE_STORAGE_RO`、
`network-address.txt=NOT_ASSIGNED`だった。強制電源断後にp2全領域をreadbackし、
SHA-256 `b4fcd46c9d8ad960932d47fea3c7ce355726eb8a7ab5e83b3a4f60ead85ba620`、
`e2fsck -fn` errorなしを確認した。

persistent logは`S34_WIFI_MODULE_LOADED`、`S35_WIFI_INTERFACE_READY`の後、
`E36_WPA_START_FAILED`を記録した。kernel logではSDIO chip `0xa9a6`と`wlan0`の生成後、
interface up時にdriverが自動選択した次のpathを開けずfirmware downloadが失敗していた。

```text
/etc/firmware/fw_bcm43438a1.bin
/etc/firmware/nvram_ap6212a.txt
/etc/firmware/clm_bcm43438a1.blob
```

stock firmware inventoryにはCLM名のfileは存在しないため、必須のhash固定AP6330 firmwareと
NVRAMをdriver自動選択名でもSYSTEMへ配置する。加えて、link up失敗を無視せず
`E35_WIFI_INTERFACE_UP_FAILED`として停止・永続化する。

corrective personalized imageはFAT/ext4再抽出、filesystem check、診断専用manifest、
config byte一致、mode 0600、full image checksum、baseとのboot領域byte一致、
平文password非混入に合格した。

## Second physical network boot

source `2abc1c6`のcorrective imageでは共通plumOS logoと`S39`を確認した。p2 readbackは
1,593,835,520 bytes、SHA-256
`6847393aa6888a40525bc91322dd26b5d805f6735339b82e6e6c2e1b9aa3af36`で、
`e2fsck -fn` errorなしだった。

stageは`S34_WIFI_MODULE_LOADED`、`S35_WIFI_INTERFACE_READY`、`S36_WPA_STARTED`から
`E37_WIFI_ASSOCIATION_TIMEOUT`へ進んだ。一方kernel logはhash固定firmware/NVRAMのopen、
NVRAM download、firmware起動、指定APへの`Link UP`、`connection succeeded`を記録した。
したがってradio/credential失敗ではない。

SYSTEMには`wpa_cli`が`/usr/sbin/wpa_cli`として収録されるが、initは存在しない
`/usr/bin/wpa_cli`をstderr破棄で呼んでいた。正しいpathへ修正し、association poll結果を
bounded intervalで`plumos-wifi.log`へ保存する。

## Third corrective host build

source `ed9549b`で`/usr/sbin/wpa_cli`の使用をtestで固定し、10 pollごとの
association statusをpersistent logの元になる`/run/plumos-wifi.log`へ追加した。
base imageは独立verifierに合格し、private imageはext4 `e2fsck -fn`、config byte一致、
mode 0600、full-image checksum、baseとのboot領域553,648,128 bytesの一致、
平文password非混入に合格した。このlatest imageのphysical bootは次のgateとする。

## Third physical network boot

source `ed9549b`のprivate seedをcold bootし、共通plumOS logoとBusyBox promptを確認した。
Macから`192.168.10.101`のARP MAC `6c:21:a2:59:45:d6`を照合し、pingとTCP 22、
root SSH loginに合格した。

SSHから次を読み戻した。

- `wpa_state=COMPLETED`、WPA2-PSK、AP channel 12、`192.168.10.101/24`
- default route `192.168.10.1`、DHCP lease 172800 seconds
- `S30_SYSTEM_ENTRY`から`S39_RECOVERY_IDLE_STORAGE_RO`まで全stage連続成功
- FAT `network-address.txt=192.168.10.101`
- `/flash` vfat、`/storage` ext4、SYSTEM SquashFSはすべてread-only
- Dropbearはdevice-sideで初回host keyを生成・永続化しTCP 22で稼働
- device上のimage/System/seed manifestはsource `ed9549b`、SYSTEM SHA-256
  `49514b6454e84f0e2efdbdcb549df64bd416c1b83e1de76516dad7e6ddb09bc2`、
  `final_partition_contract=no`、`first_boot_provisioning=not-included`、`publishable=no`で一致

kernel logはhash固定firmware/NVRAMのopen、`Link UP`、`connection succeeded`を再度記録した。
SSHから`sync; poweroff`を実行し、Macから2回目のpollでping unreachableを確認した。
SDをhostへ戻した後のFAT/ext4 clean checkは未実施である。
