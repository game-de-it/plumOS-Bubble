# 0001: V90S由来の4 partition ownershipを採用する

Date: 2026-09-01  
Status: Accepted direction; exact geometry and p2 format are pending boot-probe validation

## Context

BubbleのstockOSベースCFWは、16 MiBのraw Rockchip boot prefix、FAT32 boot partition、
ext4 storage partitionというMBR layoutで起動する。FAT32上の約1.90 GiB `SYSTEM`を
SquashFS rootとして使用し、2枚目のSDをROM領域として利用できる。

V90Sの現行plumOSは次の境界を実機で検証済みである。

- raw boot substrateは通常updateから外す。
- p1 `PLUMBOOT`にboot resourceとSystem A/Bを置く。
- p2 `BOOT`にkernel、DTB、initramfsのmatching boot payloadを置く。
- p3 `PLUMOS_SYS` ext4にmanaged runtime、state、rollback metadataを置く。
- p4 `PLUMOS` FAT32をmacOS/Windowsから見えるuser/update領域にする。
- update archiveはp4へ置き、p3 transactionまたはp1 inactive System slotへ適用する。

BubbleもSD2を利用できるため、portable contentをboot/update stateから分離する考え方と
相性がよい。一方、V90SはAllwinner boot0/boot-packageとAndroid boot partitionを使い、
BubbleはRockchip U-Bootが現在p1上の`Image`、DTB、boot scriptを読む。この物理boot形式は
同一ではない。

## Decision

BubbleはV90Sの4 partition ownershipとupdate/rollback契約を採用する。Allwinner固有の
offset、boot0、boot-package、partition imageはコピーせず、Bubbleで採取したexact Rockchip
artifactから実装する。

候補layoutは次のとおりとする。

```text
raw sectors 0..32767       16 MiB exact Bubble Rockchip prefix, immutable input
p1 PLUMBOOT    FAT32       boot resources + signed System A/B
p2 BOOT        raw         matching Bubble kernel + DTB + initramfs/recovery bundle
p3 PLUMOS_SYS  ext4        managed runtime/state; seed then expand to 8192 MiB candidate
p4 PLUMOS      FAT32       remaining SD1 capacity; user content + update inbox + logs
SD2                         optional ROM/BIOS/media source; not required for boot/update
```

役割と番号は採用するが、次の値はまだ固定しない。

- p1 size: 2つのsigned System slot、manifest、readback余裕からbuild時に算出する。
- p2 size/format: Bubble U-Bootがraw partitionから安全にloadでき、recoveryが成立した後に固定する。
- p3 seed size: strict app-layerの実使用量と最低free-spaceから決める。first-boot targetは
  V90S/Pixel2実績の8192 MiBを第一候補とする。
- partition table: 現CFWはMBRだが、4 partitionとraw prefixを維持できるため、GPTへ変更する
  必然性はまだない。boot ROM/U-Boot compatibilityで決める。

現CFWの`SYSTEM`は2,038,734,848 bytesである。これをそのままA/B化すると2 slotだけで
約3.80 GiBになるため、V90Sのp1=1024 MiBは流用できない。最終plumOS Systemが小さく
なっても、p1は次のgateで決める。

```text
p1 usable bytes
  >= 2 * maximum signed System slot bytes
     + boot resource bytes
     + temporary inactive-slot write/readback margin
     + documented growth reserve
```

## Update ownership

- Normal Runtime Update: p4 `updates/`から読み、p3上でjournaled transaction、1世代rollback。
- Normal System Update: p1のinactive slotだけへ書き、full readback hash後にpendingをp3へcommit。
- Boot Update: raw prefix/p2/kernel/DTB/initramfsをmatching setとして扱う。独立したrecoveryが
  実証されるまではnormal update対象にせず、完全SD imageでのみ更新する。
- User data: active config、save/state、credential、PortMaster/Pyxel user environmentは
  managed payloadで上書きしない。

## SD2 policy

SD2はROM、BIOS、mediaの追加sourceとして利用するが、次を守る。

- SD1 p4だけでもboot、update、recovery、最低限のgame pathが成立する。
- block番号を固定せず、SD1 parent、filesystem label/UUID、slot/controllerを照合する。
- SD2が欠落、dirty、unsupported filesystemでもSD1 bootを止めない。
- dirty mediaを自動修復しない。read-onlyまたは警告へ落とす。
- SD1 p4とSD2に同じcontentがある場合のprecedenceとsave ownerを明示する。

## Gates before implementation

1. exact 16 MiB prefix、U-Boot environment、boot source selectionを記録する。
2. 現p1 `Image`/DTB bootと候補p2 raw bootの切替を複製SDで実証する。
3. p2 failure時のprevious boot payloadまたはrecovery routeを実証する。
4. strict System/app-layer build後にp1/p3容量を計算する。
5. first-boot provisioningを中断・再開可能にし、既存p4/SD2をformatしない。
6. macOS/Windowsでp1とp4だけが通常mount対象になることを確認する。

## Consequences

V90Sの更新実績をBubbleへ持ち込める一方、初期bring-upでpartitionを先に作り込むことは
しない。最初は現CFWと同じp1 file bootを維持し、one-shot probeでboot ownershipを証明する。
p2 raw bootを成立させてから最終4 partition seedへ進む。

