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
- [x] `BUB-P0-05` preserved / replaceable / unknown の path・partition ownership 表を、SD capture 後のhash付きで確定する。
- [ ] `BUB-P0-06` original OS SD、ROM SD、ROM、BIOS、save、credential、active config の書き込み禁止境界を利用者と確認する。

## P1: stock media capture and recovery

- [x] `BUB-P1-01` OS SD を macOS へ接続し、disk identifier、physical/sector size、MBR、partition LBA、unpartitioned region を read-only で採取する。
- [ ] `BUB-P1-02` original OS SD の sector image または復元に必要な全領域を採取し、SHA-256 と readback を記録する。
  - Macが1 SD slotのためdevice-to-device clone必須とはせず、起動中stock SDからbounded boot
    substrateをSSH captureし、hostへ固定してから新SDへseed imageを書く方式を採用する。
  - raw 16 MiBとactive boot matching setは取得済み。offline full recovery imageは未取得。
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
  - 2 partition/2 GiB bring-up seedは拡張なしのdiagnostic-onlyで、正式layoutへ流用しない。
  - 正式seedはV90S同様にp1〜p3だけを収録し、初回bootでp3を8 GiB候補へ拡張して
    残領域にp4を作る。中断再開と未知p4/SD2非破壊をhost fixtureで先に検証する。
  - stock embedded initramfsは`SYSTEM_IMAGE=`に対応するがstorageをp2固定するため、
    p3 runtimeにはexternal provisioning initramfsが必要とhash固定解析で確定した。
  - external initramfsのread-only one-shotとしてp1=512 MiB、p2 raw=64 MiB、
    p3 ext4=1536 MiBをhost build/verifyした。これは容量・p2形式の最終決定ではない。
- [ ] `BUB-P1-08` sector image から複製 OS SD を作り、write後block readbackを実施する。
- [ ] `BUB-P1-09` 複製 SD で cold boot、LCD、controller、audio、AP6330 Wi-Fi、SSH、ROM SD mount を物理確認する。
  - external initramfs 3 partition probeでcold boot、共通logo、AP6330 association、DHCP、
    SSHは合格。controller、audio、ROM SDはこのminimal recovery gateでは未確認。
- [ ] `BUB-P1-10` known-good SD 交換、boot log、SSH、可能なら UART を含む recovery procedure を実証する。

## P2: boot chain and ownership probe

- [ ] `BUB-P2-01` Boot ROM -> loader -> U-Boot -> kernel -> initrd/early init -> `SYSTEM` -> systemd -> FE の実行経路を証明する。
- [ ] `BUB-P2-02` U-Boot の boot source selection、environment、root UUID、initrd variables、fallback を記録する。
- [ ] `BUB-P2-03` boot milestone を serial/FAT/persistent log に記録し、cold/warm boot baseline を測る。
  - U-Boot console `S10..E20`、systemd/frontend `S40..S90/E80`の二系統probeとclone-only guardを実装済み。
  - 初回cold bootでminimal Systemのpersistent/FAT `S30..S39`を実証済み。
  - stock U-Bootの`fatwrite`は`S19\n`の孤立clusterを作ったため廃止し、UART/consoleと
    early-init由来の記録に限定する。
  - warm bootと時間baselineは未実施。
  - external initramfs用にU-Boot `S12/E12` initrd、`S13/E13` kernel、`S14/E14` DTB、
    early userspace `S21..S29/E23..E29`とp3 persistent logをhost検証済み。
- [ ] `BUB-P2-04` 起動中 CFW の process、mapped library、device fd、mount ownership 表を完成する。
- [x] `BUB-P2-05` 複製 SD に可逆な one-shot diagnostic System/entry を実装する。
  - AArch64 static BusyBox、stock handoff互換entrypoint、FAT/ext4/console/kmsg stage、
    framebuffer `S33` markerを持つ最小Systemと2 GiB seed imageをhost build/verifyした。
  - 新SDでphysical cold bootし、FAT `S39`、p2の全stage、clean ext4、BusyBox promptをreadback確認した。
- [x] `BUB-P2-06` stock FE を開始せず、plumOS marker、log、recovery SSH を保持できることを実機確認する。
  - stock FEを開始せず、framebuffer marker、persistent log、BusyBox promptまでは実証済み。
  - AP6330、bounded WPA/DHCP、Dropbear recovery SSHを次seedへ実装しhost検証済み。
  - device-owned credential入りpersonalized imageで実機Wi-Fi/DHCP/SSHを確認済み。
  - 初回network seedはmodule loadと`wlan0`生成後、driver自動選択firmware path不在で
    `E36_WPA_START_FAILED`。p2 readbackはcleanで、固定名aliasと正確なE35判定を追加中。
  - 2回目はfirmware/NVRAM download、WPA開始、APへのlink upまで成功したが、SYSTEM内の
    `/usr/sbin/wpa_cli`を`/usr/bin/wpa_cli`で呼んだため接続完了を検出できず`E37`。
  - `wpa_cli` pathを修正し、bounded association status logを追加したsource `ed9549b`の
    private seedで`S30..S39`、WPA2 association、DHCP `.101`、Dropbear SSH、FAT IP marker、
    p1/p2 read-onlyを実機確認し、SSHからのnormal poweroffを実施した。
- [ ] `BUB-P2-07` probe failure を意図的に起こし、original/known-good SDへ確実にrollbackできることを確認する。
- [ ] `BUB-P2-08` preserved vendor substrate と plumOS-owned boundary の architecture decision record を確定する。

## P3: reproducible plumOS System

- [ ] `BUB-P3-01` clean container から AArch64 Bubble System を再現 build する。
  - full Systemに先立つminimal diagnostic Systemは専用arm64 containerから再現build済み。
- [ ] `BUB-P3-02` vendor artifact を hash、source identity、license、capture procedure 付きの外部入力として固定する。
- [ ] `BUB-P3-03` read-only System A/B、atomic slot metadata、checksum verification を実装する。
- [ ] `BUB-P3-04` `/run`、`/tmp`、managed persistent、mutable config、user media の mount contract を実装する。
- [ ] `BUB-P3-05` plumOS supervisor、boot log、visible error screen、recovery SSH を実装する。
- [ ] `BUB-P3-06` Bubble root/app-layer manifest と `checksums.sha256` を生成・検証する。
  - frontend、RetroArch、QuickNESのcomponent manifest/checksumと全app-layer checksumを
    host生成し、p3からの独立readback verifierと実機bootstrapに合格した。
- [ ] `BUB-P3-07` componentごとの loader/library path を固定し、global `LD_LIBRARY_PATH` fallback を禁止する。
  - frontendは`frontend/lib`、RetroArch/amixerは`emulator/lib`だけを各launcherで設定し、
    GPU library非依存をELF検証済み。実機mapped-library確認を残す。
- [ ] `BUB-P3-08` intentional System/app checksum failure で SSH/log が残り、stock FE が起動しないことを実機確認する。
- [ ] `BUB-P3-09` device-owned config/save/credential が System deploy 前後で不変であることをhash/semantic checkする。

## P4: Bubble hardware profile

### Display/GPU

- [ ] `BUB-P4-D01` DRM connector/CRTC/plane/format/stride/modifier を read-only probe で採取する。
- [ ] `BUB-P4-D02` CPU-rendered DRM dumb-buffer double buffering と page-flip completion を実装する。
  - MFの共通rendererとRetroArch DRM修正をBubbleへ移植し、FEとRetroArch RGUIの実パネル表示、
    DRM handoff、FEへの再取得まで確認した。page-flip継続計測を残す。
- [ ] `BUB-P4-D03` 640x480 panel の実 refresh、scroll pacing、input-to-visible response を測定する。
- [ ] `BUB-P4-D04` fbdev/DRM handoff、FE/game/menu、終了後のscanout ownershipを物理確認する。
- [ ] `BUB-P4-D05` vendor `libmali` のlicense、redistribution、DDK/kernel ABIを監査し、採用・隔離・不採用を決定する。

### Input

- [ ] `BUB-P4-I01` `event0..3` と `js0/js5` の capability を machine-readable inventory にする。
- [ ] `BUB-P4-I02` 全物理button、D-pad、ABXY、shoulder、START/SELECT、analog、stick click をpress/release採取する。
- [ ] `BUB-P4-I03` `gpio-keys`、power key、G-sensor、rumble の物理対応と必要性を確定する。
- [ ] `BUB-P4-I04` hotkey、volume、brightness、menu、exit の競合しない ownership policy を決める。
- [ ] `BUB-P4-I05` normalized Bubble controller を公開し、FE/RetroArch/standaloneで1入力1反応を確認する。
  - FEとRetroArch RGUIでD-pad/A/B、SELECT+START終了を物理確認した。standaloneと全buttonを残す。

### Audio/power

- [ ] `BUB-P4-A01` RK817 mixer controls、speaker/headphone route、jack detect、safe gain を採取する。
  - exact control存在時だけ`Resume Path=ON`、`Playback Path=SPK`、`SPK=40%`を行う
    guarded bring-upを実装。Bubble実機のcontrol/readbackとheadphone routeは未確認。
- [ ] `BUB-P4-A02` supported rate/format、hardware pointer、XRUN、5分継続を speaker で確認する。
- [ ] `BUB-P4-A03` headphone 接続/抜去、ゲーム終了、suspend/resume 後の route 復帰を確認する。
- [ ] `BUB-P4-P01` backlight 0..255 の安全範囲、段階、persist policy を決める。
- [ ] `BUB-P4-P02` battery/charger node、capacity、charging状態、volume/power keyをhelperへ閉じ込める。
- [ ] `BUB-P4-P03` normal shutdown/reboot、charger接続前後、cold boot、suspend/resumeを実機確認する。
- [ ] `BUB-P4-P04` power action後にFAT/ext4がcleanであることを次boot/read-only fs checkで確認する。

### Network/USB/storage

- [ ] `BUB-P4-N01` AP6330 firmware/NVRAM/module/runtime ownership を固定する。
  - stock hash/vermagic固定の`bcmdhd.ko`、firmware、NVRAMをdevelopment seedへ隔離して組み込み済み。
  - 実機load/associationと再配布license判断は未完了。
- [ ] `BUB-P4-N02` first connect、credential persist、cold boot reconnect、Wi-Fi OFF persist、bounded recovery を確認する。
- [ ] `BUB-P4-N03` USB host/device/charging controller と同時利用制約を調査し、product policy を決める。
- [ ] `BUB-P4-S01` OS SD と ROM SD を UUID/label/partition identity で安全に解決する。
- [ ] `BUB-P4-S02` dirty ROM SD を自動修復せず、警告・read-only・退避手順を定義する。

## P5: frontend and NES baseline

- [ ] `BUB-P5-01` Bubble 640x480 frontend profile と runtime DRM discovery を実装する。
  - CPU DRM、runtime connector/mode discovery、Bubble物理A/B mappingをhost build済み。
    `S39..E81`、input trace、frame statsを次のphysical gateへ組み込み済み。
- [ ] `BUB-P5-02` FEのinput、audio、brightness/volume、power menu ownershipをBubble helperへ接続する。
- [ ] `BUB-P5-03` Bubble向けRetroArchとQuickNESをpinned sourceからbuildしcomponent manifestを生成する。
  - RetroArch v1.22.2とQuickNES `058d665`をAArch64 containerからbuildし、
    software DRM/RGUI/ALSA/udev、GPU runtime非依存、component checksumをhost検証済み。
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

- [x] U-Boot FAT marker失敗に依存しないearly-init cmdline/device/process snapshotを追加する。
- [x] minimal SystemへAP6330 firmware/module、bounded network設定、Dropbear recovery SSHを追加する。
- [ ] personalized recovery-network seedをSDへwrite/readbackする。
- [x] Bubble独自S33画面を廃止し、V90S/A30/MF共通plumOS logoのexact assetへ置換・検証する。
- [x] diagnostic seedを正式layoutからmanifest/verifierで機械的に区別し、release対象にしない。
- [ ] V90S型first-boot provisioningとSystem A/B/update metadataをBubble geometryへ移植する。
- [x] partition変更を行わないexternal initramfs one-shot、p1 System A/B、p2 raw matching bundle、
  p3 runtimeの3 partition probeを再現buildし、独立readback verifierへ合格させる。
- [ ] private 3 partition probeを新SDへfull write/readbackし、実機で`S21..S39`、Wi-Fi、SSH、
  normal shutdown、p1/p2不変、FAT/ext4 cleanを確認する。
  - `S21..S39`、Wi-Fi、SSH、exact geometry、System A/B、p2 runtime hash、normal shutdownは合格。
    poweroff後のoffline p1/p2 hashとFAT/ext4 fsckを残す。
- [ ] cold bootし、Wi-Fi association、DHCP、SSH、log、normal shutdown後のext4 cleanを確認する。
  - association、DHCP、SSH、persistent log、normal shutdown、SD readbackのext4 cleanは合格。
  - normal poweroff後、macOS `diskutil verifyVolume`のread-only `fsck_msdos -n`でp1 FATもclean。
- [ ] frontend/RetroArch/QuickNES private probeをRaspberry Pi Imagerでwriteし、1回のcold bootで
  FE表示、Bubble入力、RetroArch RGUI、利用者提供NESのQuickNES video/input/audio、FE復帰、
  Wi-Fi/SSH、`S39..S79`とerror-free kernel logを確認する。
  - source `eee3d8c`のlive deploy後、共通logoからFE表示、共通START 7項目、Bubble入力、
    RetroArch RGUI、DRM/udev controller/ALSA device取得、SELECT+START `rc=0`、FE 1 process復帰、
    Wi-Fi/SSH、app-layer checksumを実機確認した。
  - QuickNES ROM video/input/audio、speaker実聴、save/state、F/Mode menuを残す。
- [x] 共通plumOS START項目を未実装を理由に削除しない方針を固定し、Bubbleへ
  UI設定、システム設定、ネットワーク設定、アプリ、ヘルプ、再起動、シャットダウンを復元する。
