# Bubble recovery-network seed host validation

Date: 2026-09-01  
Source commit: `9a81427`  
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
sha256=c9a7cef9ba4538b5708a181c8d7bfe4ff77c1f6801c3c93ea79fe78933c6c4a9
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
sha256=52b3b8d2bce4a63cd5b0307a8deec3f72fc4b7a49ccab40ceace3c7d0f8a4495
boot_filesystem_sha256=5a73f288dfd08c8952058a97543689dd55259fab402775b365c1a62ff80f94c6
sys_filesystem_sha256=f8d325070de4e205306d00890a560770691a88a91a89986107aa14355dac1978
```

independent verifierはRockchip prefix、MBR、FAT/ext4、SYSTEM readback、root UUID、seed markerを
確認した。共通imageとrepositoryにはSSID、PSK、平文passwordを含めていない。

## Private personalization

利用者指定WLAN credentialをrepository外でWPA-PSKへ変換し、base imageを変更せず、別imageの
p2 `/plumos/config/wpa_supplicant.conf`へmode 0600で注入した。credential内容と単独hashは
manifestへ記録しない。

```text
file=output/image/bubble/plumOS-Bubble-0.1.0-dev-seed-wifi.img
size=2147483648
sha256=9f02092f2dfad18ed0275b84acf977dcb9759e4290ccdf93985768eccbf21c09
base_image_sha256=52b3b8d2bce4a63cd5b0307a8deec3f72fc4b7a49ccab40ceace3c7d0f8a4495
publishable=no
```

personalized p2を再抽出し、`e2fsck -fn` clean、config byte一致、mode 0600、full image checksum、
平文password非混入を確認した。このimageはprivate physical bring-up専用で公開しない。
