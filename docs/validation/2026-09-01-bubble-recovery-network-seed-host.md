# Bubble recovery-network seed host validation

Date: 2026-09-01; corrective build 2026-09-02
Source commit: `2abc1c6`

Scope: host build、private personalization、初回physical失敗解析。
corrective buildのphysical Wi-Fi/SSHは未実施。

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
sha256=a3f24f7c44e5678ef56f8721a2bbddb8e82517557241fb7c976369631fa19747
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
確認した。corrective source `2abc1c6`では次のimageを生成し、独立verifierに合格した。

```text
file=output/image/bubble/plumOS-Bubble-0.1.0-dev-seed.img
size=2147483648
sha256=0ca39d42fd83fa0459da38f6e8f755405a3cde5d0ef6d79b0dbcca32580ae76e
boot_filesystem_sha256=9c5ac46eec7d93e3a80561e7a33d7d4cd42faa7f9056dba8c65d5d0660ded116
sys_filesystem_sha256=b60141b066c5547a3d68ff0bb722dd4f2d1ae6dfae7c39535e91e399ad31eff6
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
sha256=7f2d2d94650fa79d2852f5ed517dfbf659a1441aa2835334cf36d1654c45c7b4
base_image_sha256=0ca39d42fd83fa0459da38f6e8f755405a3cde5d0ef6d79b0dbcca32580ae76e
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
