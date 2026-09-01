# TODO

この一覧は GKD Bubble port の実行順序と acceptance gate を管理する。
`[x]` は文書作成だけでなく、必要な build、deploy/readback、実機確認まで完了した場合に限る。
詳細設計は `docs/plumos-bubble-porting-plan.md`、初回観測は
`docs/validation/2026-09-01-bubble-read-only-inventory.md` を参照する。

## P0: repository and read-only baseline

- [x] `BUB-P0-01` repository rules と他6機種の移植ガイド、計画、TODO、Git履歴を調査する。
- [x] `BUB-P0-02` 起動中 CFW を SSH から読み取り専用で調査し、boot/storage/process/hardware inventory を記録する。
- [x] `BUB-P0-03` Bubble porting plan と phase gate を作成する。
- [x] `BUB-P0-04` Git repository を初期化し、local artifact/output を除外する。
- [x] `BUB-P0-05A` V90S由来のp1 boot/System A/B、p2 matching boot、p3 ext4 runtime、
  p4 FAT32 user/update、optional SD2というownership方向を採用する。
- [ ] `BUB-P0-05` preserved / replaceable / unknown の path・partition ownership 表を、SD capture 後のhash付きで確定する。
- [ ] `BUB-P0-06` original OS SD、ROM SD、ROM、BIOS、save、credential、active config の書き込み禁止境界を利用者と確認する。

## P1: stock media capture and recovery

- [x] `BUB-P1-01` OS SD を macOS へ接続し、disk identifier、physical/sector size、MBR、partition LBA、unpartitioned region を read-only で採取する。
- [ ] `BUB-P1-02` original OS SD の sector image または復元に必要な全領域を採取し、SHA-256 と readback を記録する。
- [ ] `BUB-P1-03` ROM SD は filesystem metadata と dirty state だけを read-only で確認し、ROM/BIOS/save 内容を repository や build artifact に取り込まない。
- [ ] `BUB-P1-04` raw Rockchip prefix、IDBLoader/SPL、U-Boot、environment の offset/size/hash を特定する。
  - 先頭16 MiBをread-only取得し、exact size、SHA-256、RKNS/FIT/BL3X主要headerを確認済み。
  - prefix内のdefault文字列では`mmc1 -> mmc0 -> usb0 -> pxe -> dhcp`と
    `boot.scr.uimg`/`boot.scr`探索を確認したが、active environmentの保存場所と冗長性は未確認。
- [x] `BUB-P1-05` `Image`、`SYSTEM`、`boot.scr/cmd`、`uEnv.txt`、全 DTB/DTBO の hash/provenance manifest を作成する。
  - active `Image`、通常/HDMI DTB、適用overlay/fixup、U-Boot DTB、boot scriptをhash照合してlocal artifactへ取得済み。
  - stock `SYSTEM`はanalysis-only hashだけを記録し、vendor/release outputへコピーしていない。
  - stock CFW `/flash/dtbs`の全56 DTB/DTBOをpath/size/hash inventoryへ固定済み。
  - vendor artifactのsource identity/license/redistribution判断は`BUB-P3-02`で継続する。
- [x] `BUB-P1-06` runtime device tree を採取し、selected `rk3566-gkd-geek-bbg.dtb` + overlays と比較する。
- [x] `BUB-P1-07` `/proc/config.gz`、module、firmware、vendor Mali userspace の ABI inventory を固定する。
  - module 556 files、firmware 322 filesのsize/hash inventoryと、起動に関係する固定ABI候補を取得済み。
  - vendor artifactのsource identity/license/redistribution判断は`BUB-P3-02`と`BUB-P4-D05`で行う。
- [ ] `BUB-P1-07A` 現SYSTEMと生成plumOS Systemの実サイズからp1 A/B容量を計算し、
  Bubble U-Boot/recovery proofからp2容量・形式を固定する。
- [ ] `BUB-P1-08` sector image から複製 OS SD を作り、write後block readbackを実施する。
- [ ] `BUB-P1-09` 複製 SD で cold boot、LCD、controller、audio、AP6330 Wi-Fi、SSH、ROM SD mount を物理確認する。
- [ ] `BUB-P1-10` known-good SD 交換、boot log、SSH、可能なら UART を含む recovery procedure を実証する。

## P2: boot chain and ownership probe

- [ ] `BUB-P2-01` Boot ROM -> loader -> U-Boot -> kernel -> initrd/early init -> `SYSTEM` -> systemd -> FE の実行経路を証明する。
- [ ] `BUB-P2-02` U-Boot の boot source selection、environment、root UUID、initrd variables、fallback を記録する。
- [ ] `BUB-P2-03` boot milestone を serial/FAT/persistent log に記録し、cold/warm boot baseline を測る。
- [ ] `BUB-P2-04` 起動中 CFW の process、mapped library、device fd、mount ownership 表を完成する。
- [ ] `BUB-P2-05` 複製 SD に可逆な one-shot diagnostic System/entry を実装する。
- [ ] `BUB-P2-06` stock FE を開始せず、plumOS marker、log、recovery SSH を保持できることを実機確認する。
- [ ] `BUB-P2-07` probe failure を意図的に起こし、original/known-good SDへ確実にrollbackできることを確認する。
- [ ] `BUB-P2-08` preserved vendor substrate と plumOS-owned boundary の architecture decision record を確定する。

## P3: reproducible plumOS System

- [ ] `BUB-P3-01` clean container から AArch64 Bubble System を再現 build する。
- [ ] `BUB-P3-02` vendor artifact を hash、source identity、license、capture procedure 付きの外部入力として固定する。
- [ ] `BUB-P3-03` read-only System A/B、atomic slot metadata、checksum verification を実装する。
- [ ] `BUB-P3-04` `/run`、`/tmp`、managed persistent、mutable config、user media の mount contract を実装する。
- [ ] `BUB-P3-05` plumOS supervisor、boot log、visible error screen、recovery SSH を実装する。
- [ ] `BUB-P3-06` Bubble root/app-layer manifest と `checksums.sha256` を生成・検証する。
- [ ] `BUB-P3-07` componentごとの loader/library path を固定し、global `LD_LIBRARY_PATH` fallback を禁止する。
- [ ] `BUB-P3-08` intentional System/app checksum failure で SSH/log が残り、stock FE が起動しないことを実機確認する。
- [ ] `BUB-P3-09` device-owned config/save/credential が System deploy 前後で不変であることをhash/semantic checkする。

## P4: Bubble hardware profile

### Display/GPU

- [ ] `BUB-P4-D01` DRM connector/CRTC/plane/format/stride/modifier を read-only probe で採取する。
- [ ] `BUB-P4-D02` CPU-rendered DRM dumb-buffer double buffering と page-flip completion を実装する。
- [ ] `BUB-P4-D03` 640x480 panel の実 refresh、scroll pacing、input-to-visible response を測定する。
- [ ] `BUB-P4-D04` fbdev/DRM handoff、FE/game/menu、終了後のscanout ownershipを物理確認する。
- [ ] `BUB-P4-D05` vendor `libmali` のlicense、redistribution、DDK/kernel ABIを監査し、採用・隔離・不採用を決定する。

### Input

- [ ] `BUB-P4-I01` `event0..3` と `js0/js5` の capability を machine-readable inventory にする。
- [ ] `BUB-P4-I02` 全物理button、D-pad、ABXY、shoulder、START/SELECT、analog、stick click をpress/release採取する。
- [ ] `BUB-P4-I03` `gpio-keys`、power key、G-sensor、rumble の物理対応と必要性を確定する。
- [ ] `BUB-P4-I04` hotkey、volume、brightness、menu、exit の競合しない ownership policy を決める。
- [ ] `BUB-P4-I05` normalized Bubble controller を公開し、FE/RetroArch/standaloneで1入力1反応を確認する。

### Audio/power

- [ ] `BUB-P4-A01` RK817 mixer controls、speaker/headphone route、jack detect、safe gain を採取する。
- [ ] `BUB-P4-A02` supported rate/format、hardware pointer、XRUN、5分継続を speaker で確認する。
- [ ] `BUB-P4-A03` headphone 接続/抜去、ゲーム終了、suspend/resume 後の route 復帰を確認する。
- [ ] `BUB-P4-P01` backlight 0..255 の安全範囲、段階、persist policy を決める。
- [ ] `BUB-P4-P02` battery/charger node、capacity、charging状態、volume/power keyをhelperへ閉じ込める。
- [ ] `BUB-P4-P03` normal shutdown/reboot、charger接続前後、cold boot、suspend/resumeを実機確認する。
- [ ] `BUB-P4-P04` power action後にFAT/ext4がcleanであることを次boot/read-only fs checkで確認する。

### Network/USB/storage

- [ ] `BUB-P4-N01` AP6330 firmware/NVRAM/module/runtime ownership を固定する。
- [ ] `BUB-P4-N02` first connect、credential persist、cold boot reconnect、Wi-Fi OFF persist、bounded recovery を確認する。
- [ ] `BUB-P4-N03` USB host/device/charging controller と同時利用制約を調査し、product policy を決める。
- [ ] `BUB-P4-S01` OS SD と ROM SD を UUID/label/partition identity で安全に解決する。
- [ ] `BUB-P4-S02` dirty ROM SD を自動修復せず、警告・read-only・退避手順を定義する。

## P5: frontend and NES baseline

- [ ] `BUB-P5-01` Bubble 640x480 frontend profile と runtime DRM discovery を実装する。
- [ ] `BUB-P5-02` FEのinput、audio、brightness/volume、power menu ownershipをBubble helperへ接続する。
- [ ] `BUB-P5-03` Bubble向けRetroArchとQuickNESをpinned sourceからbuildしcomponent manifestを生成する。
- [ ] `BUB-P5-04` 利用者提供の小さな既知正常NES content 1本だけをGit外からtest deploymentする。
- [ ] `BUB-P5-05` FE -> QuickNES -> FE のdisplay/input/audio lifecycleを実機確認する。
- [ ] `BUB-P5-06` menu/exit、save/state、reboot後の保持を確認する。
- [ ] `BUB-P5-07` game終了後にfrontendが1 processだけで、DRM/input/audio owner残留がないことを確認する。

## P6: wider runtime and compatibility

- [ ] `BUB-P6-01` software DRM pathでbaseline libretro systemsを1 systemずつ追加・実機確認する。
- [ ] `BUB-P6-02` PicoArch、standalone、Pyxel を component-scoped runtime として個別評価する。
- [ ] `BUB-P6-03` GPU必須runtimeはvendor Mali componentまたは将来のopen GPU routeへ隔離する。
- [ ] `BUB-P6-04` enabled system/core/BIOS/content policyをmanifest化し、存在しないruntimeをFEに表示しない。
- [ ] `BUB-P6-05` PortMaster static audit、loader/env/session guard、代表runtimeの実機確認を行う。
- [ ] `BUB-P6-06` app/game終了時に同一sessionだけを回収し、frontend/device ownershipを復元する。

## P7: update, lifecycle and release

- [ ] `BUB-P7-01` signed package、downgrade拒否、System A/B、app-layer journal/rollbackを実装する。
- [ ] `BUB-P7-02` boot/kernel/DTB/module/System matching-set updateとrecoveryを設計・実機検証する。
- [ ] `BUB-P7-03` normal、tamper、disk full、中断、bad slot、health failure、old version updateを試験する。
- [ ] `BUB-P7-04` factory defaultとactive user configを分離し、update/factory reset policyを確定する。
- [ ] `BUB-P7-05` clean cloneからimageを再現し、source completeness、license、secret/ROM/BIOS混入gateを通す。
- [ ] `BUB-P7-06` SD write/readback、cold boot 3回、warm reboot、rollback、全hardware acceptanceを完了する。
- [ ] `BUB-P7-07` release candidateを利用者が物理確認し、未解決項目を明示する。
- [ ] `BUB-P7-08` 利用者の明示承認後だけreleaseを公開し、公開assetを再downloadしてchecksumを確認する。

## Next action

- [ ] U-Boot active environment、initrd handoff、起動中process/library/device ownershipをread-onlyで特定する。
- [ ] 別の複製用SDを用意し、original OS SDのdevice-to-device cloneとreadbackを行う。
