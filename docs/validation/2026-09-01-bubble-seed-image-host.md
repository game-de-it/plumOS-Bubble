# Bubble stock-substrate seed image host validation

Date: 2026-09-01  
Scope: one-slot workflow向けhost build。physical SD write/bootは未実施。

## Result

Mac側に既にread-only captureしたBubble stock boot substrateから、2 GiBの開発用seed imageを
生成した。stock `SYSTEM`やstock userlandは含めず、新規の最小plumOS userlandを`/SYSTEM`へ
配置した。

```text
raw sectors 0..32767  exact Bubble Rockchip payload; MBR partition tableのみseed layoutへ更新
p1 512 MiB FAT32      PLUMBOOT; stock Image/DTB/overlay + instrumented boot.scr + plumOS SYSTEM
p2 remainder ext4     PLUMOS_SYS; persistent bring-up logs only
```

これは最終V90S型4 partition layoutではない。stock built-in initramfsが理解するp1/p2 contractを
変えずに、stock boot substrateからplumOS userlandへの最初のhandoffだけを証明するための
bounded diagnostic layoutである。

## Minimal System

`SYSTEM`はAArch64 static BusyBoxとplumOS-owned `/init`からなるread-only SquashFSである。
stock initramfsのhandoff互換性のため、次を両方持つ。

- `/sbin/init -> /init`
- `/usr/lib/systemd/systemd -> /init`

`/init`はconsole、kmsg、p2 ext4、p1 FATへstageを記録し、640x480 XRGB8888 framebufferへ
`PLUMOS BUBBLE / USERLAND REACHED / STAGE S33`を描画する。最終stage後はp2をread-onlyへ
remountし、BusyBox initとserial/tty recovery shellを保持する。Wi-Fi、SSH、frontendは、
このhandoffが物理合格してから追加する。

Host build result:

```text
SYSTEM size=831488
SYSTEM sha256=68816edb5cde2ba5baf1bab4302b552410a0bd5de44bd8d01270751b0757bd98
busybox architecture=AArch64 static
source_ref=b0110c9
source_date_epoch=1788269127
```

## Seed image verification

最初のhost buildではportable shellの`printf`が`\xNN`を解釈せず、MBR disk signatureの
4 bytesではなく文字列をpartition tableへ上書きしたため、independent verifierが
`unrecognised disk label`として拒否した。octal escapeへ修正して再buildした。

完全imageの再現性確認では、最初の2回が異なるSHAとなった。`mke2fs -d`がhost側の
`ctime`をimportした4 inodeを特定し、固定した`source_date_epoch`へ正規化した。
修正commit `b0110c9`から完全imageを2回生成し、image本体と`image.manifest`の
byte-identical一致を確認した。

修正版は次のgateを通過した。

- exact 2,147,483,648-byte image
- MBR p1 `32768..1081343`、p2 `1081344..4194303`
- sector 1以降、16 MiB境界までcaptured Rockchip prefixとbyte-identical
- FAT `fsck.fat -vn` clean
- ext4 `e2fsck -fn` clean
- final imageから抽出した`SYSTEM`がhost payloadとbyte-identical
- FAT `uEnv.txt` root UUIDがp2 ext4 UUIDと一致
- seed authorization、FAT/EXT4 manifests、full image SHA-256確認

Verified development image:

```text
image=output/image/bubble/plumOS-Bubble-0.1.0-dev-seed.img
size=2147483648
sha256=730db733fe883a5fabc2176d447d57feb97bd651e22efa2dd8232374e5903a4c
boot_filesystem_sha256=918b32586ca8094e75af7e865196437e7935842f99024af719a0698006886aea
sys_filesystem_sha256=6c0cbb69a27a7f42828fb00d0803cafa267639af1bdc3c4f899e5e4a80d8cca3
source_ref=b0110c9
reproducibility=two full builds byte-identical
```

このimageはcaptured vendor boot artifactを含むため、物理bring-up専用であり公開しない。
