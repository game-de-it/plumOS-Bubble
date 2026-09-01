# Bubble recovery-network seed host validation

Date: 2026-09-01  
Source commit: `6630283`

Scope: host build and private personalization。physical Wi-Fi/SSHは未実施。

## Recovery System

初回physical handoffに合格した最小SYSTEMへ、次の一層だけを追加した。

- stock kernelとvermagicが一致するhash固定`bcmdhd.ko`
- stock boot logで使用を確認したAP6330 firmwareとNVRAM
- Debian Bookworm arm64 `wpa_supplicant`とruntime libraries
- Debian Bookworm arm64 Dropbear、persistent host key、development password login
- bounded module/interface/association/DHCP/SSH stages `S34..S38` / `E34..E38`
- network後のcmdline、mount、address、device、process、kernel snapshot

SYSTEM result:

```text
size=8032256
sha256=9fcd7655949175a59c71acb1459b7d5ae89cda2f74bd3ec4b8631307706a0eca
kernel_release=4.19.193-g5a07852a55cf-dirty
bcmdhd_sha256=fd8abaada4aed3ef140e778e344316a1727b0c8d7d9d83d0aee51e3d008297f4
wifi_firmware_sha256=c587abd06865aab98290e1bdd1e9185cfb5c30f89af329c77e0202afe4b932c1
wifi_nvram_sha256=68952ca377ea4f629c7d01042ba6d95e2c74f347a893c4d49a4d3c3f38a5bf1b
```

rootfs内chrootでWPAとDropbearのversion実行、dynamic loader/library解決、shadow mode 0600、
vendor artifact SHA、module vermagic、SquashFS必須pathを確認した。network daemonのlog fdは
tmpfs `/run`へ保持し、startup logをp2へcopyしてからp2をread-onlyへ戻す。

## Reproducible base image

同じcommitから完全imageを2回生成し、image本体とmanifestのbyte-identical一致を確認した。

```text
file=output/image/bubble/plumOS-Bubble-0.1.0-dev-seed.img
size=2147483648
sha256=570c595b5c883c9a3e9ebff5a4c2d3253ca0460318f6706dcfa728978967d628
boot_filesystem_sha256=f7a8f4900ec1d4c380ec11600079a5a0220250b079a1e374478aded7ce77c12d
sys_filesystem_sha256=409adf94c419f23e7bc11b9f65472ed892509a17bae145271f41d59eb5cb098a
```

independent verifierはRockchip prefix、MBR、FAT/ext4、SYSTEM readback、root UUID、seed markerを
確認した。FATの`plumos-probe/network-address.txt`は生成時に`NOT_ASSIGNED`で初期化し、起動時に
DHCP addressをatomic renameで記録する。共通imageとrepositoryにはSSID、PSK、平文passwordを
含めていない。

## Private personalization

利用者指定WLAN credentialをrepository外でWPA-PSKへ変換し、base imageを変更せず、別imageの
p2 `/plumos/config/wpa_supplicant.conf`へmode 0600で注入した。credential内容と単独hashは
manifestへ記録しない。

```text
file=output/image/bubble/plumOS-Bubble-0.1.0-dev-seed-wifi.img
size=2147483648
sha256=c39cb064b1b69e6c1b0bf158edaa15f331b965d57dd28e6abb317ee716d41d13
base_image_sha256=570c595b5c883c9a3e9ebff5a4c2d3253ca0460318f6706dcfa728978967d628
publishable=no
```

personalized p2を再抽出し、`e2fsck -fn` clean、config byte一致、mode 0600、full image checksum、
平文password非混入を確認した。このimageはprivate physical bring-up専用で公開しない。

## First physical network boot

personalized seedをcold bootした結果、FATは`S39_RECOVERY_IDLE_STORAGE_RO`、
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
