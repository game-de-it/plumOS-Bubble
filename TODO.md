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
  - 2304 MiB seed p3から8192 MiBへの拡張、p4作成、再実行UUID不変、p3拡張後の再開、
    durable intentなしの空p4拒否とintentありの再開をreal loop fixtureでhost検証済み。
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
  - source `24635cc`のcold bootで、FE process開始6.33秒、Wi-Fi/DHCP/SSH完了約10秒、
    FE ready約12秒を実測した。Wi-Fi完了はFE開始を阻害せず、最終FAT markerは`S40`を保持、
    current bootの`stage=E`は0件、full app-layer hashはboot中に再実行されていない。
    詳細は`docs/validation/2026-09-03-bubble-fast-boot-physical.md`。warm boot比較は未実施。
  - 同bootでexternal initramfsが完了済みp3/p4にも`e2fsck -pf`、`resize2fs`、
    `fsck.fat -a`を再実行し、p4 dirty bitを修復していたことを検出。V90S同様のpaired
    clean-shutdown marker fast pathを実装し、clean時は3処理をskip、marker欠落時だけ従来の
    recovery/resumeを実行するhost fixtureに合格。実機deploy後のclean reboot計測を残す。
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
  - development slot切替とinactive image readbackは実機合格。現状のseed-level
    `SYSTEM.manifest`/`plumos-image.manifest`は元seedを表すため、正式updaterではslot-scoped
    System manifestとactive identityをatomicに切り替える必要がある。
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
  - RGUIからcontentへ戻る際のhangは、初期のkernel stackでは`poll(2)`しか見えなかったが、
    追加したmenu/game barrier logは全て完了した。symbol付きgdb backtraceで実停止箇所を
    ALSAの`snd_pcm_wait`と確定し、DRM transition起因ではないことを確認した。DRMの
    page-flip継続計測自体は本項目に残す。
  - Core Provided/整数scale変更でviewport-sized bufferを再生成していなかった問題を修正。
    gameはCore Provided `640x480`から整数scale `576x432+32+24`へ変化し、RGUIは
    整数scaleから独立して常にpanel `640x480`となることを実機logで確認。物理LCD確認を残す。
- [ ] `BUB-P4-D03` 640x480 panel の実 refresh、scroll pacing、input-to-visible response を測定する。
- [ ] `BUB-P4-D04` fbdev/DRM handoff、FE/game/menu、終了後のscanout ownershipを物理確認する。
- [ ] `BUB-P4-D05` vendor `libmali` のlicense、redistribution、DDK/kernel ABIを監査し、採用・隔離・不採用を決定する。

### Input

- [ ] `BUB-P4-I01` `event0..3` と `js0/js5` の capability を machine-readable inventory にする。
- [ ] `BUB-P4-I02` 全物理button、D-pad、ABXY、shoulder、START/SELECT、analog、stick click をpress/release採取する。
- [ ] `BUB-P4-I03` `gpio-keys`、power key、G-sensor、rumble の物理対応と必要性を確定する。
- [ ] `BUB-P4-I04` hotkey、volume、brightness、menu、exit の競合しない ownership policy を決める。
  - V90S由来cfgの不足key追加だけでは旧RA defaultが残る問題を修正。変更されていない旧default
    だけを三者比較で移行し、利用者変更値と旧cfg backupを保持する。全エミュmenuを
    Function1へ統一し、RA screenshotはFunction2へ移動。旧managed pairだけをbackup付きで
    実機移行済み（active menu=17/screenshot=10）。物理hotkey確認を残す。
- [ ] `BUB-P4-I05` normalized Bubble controller を公開し、FE/RetroArch/standaloneで1入力1反応を確認する。
  - FEとRetroArch RGUIでD-pad/A/B、SELECT+START終了を物理確認した。standaloneと全buttonを残す。
  - PicoArch QuickNESで物理A/B、Function1/2 menu、menu A決定/B戻る、FE復帰を利用者確認済み。
    X/Y、shoulder、両stick/L3/R3、standalone固有layout、volume/powerは引き続き別gateとする。

### Audio/power

- [ ] `BUB-P4-A01` RK817 mixer controls、speaker/headphone route、jack detect、safe gain を採取する。
  - exact control存在時だけ`Resume Path=ON`、`Playback Path=SPK`、`SPK=40%`を行う
    guarded bring-upを実装。Bubble実機のcontrol/readbackとheadphone routeは未確認。
- [ ] `BUB-P4-A02` supported rate/format、hardware pointer、XRUN、5分継続を speaker で確認する。
  - QuickNES/gpSP/PCSX-ReARMed/Flycast Xtreme/YabaSanshiroでALSA `RUNNING`と
    pointer進行を実機確認した。N64 2 coreは`PREPARED`/`hw_ptr=0`のため未解決。
    route横断のspeaker実聴、XRUN、5分継続は未確認。
  - RetroArch FCEUmmのNES実聴で音飛びを確認。CPU idle 82-87%でもPCMが
    `RUNNING`から`PREPARED`へ戻るunderrunを採取したため、CPU性能設定ではなく
    DRM page-flip待ちを`video_threaded=true`でproducerから分離した。通常の
    `ondemand`で同一contentを再起動し、利用者が音飛び解消を実聴確認した。PCMは
    324秒時点まで95/95 sampleが`RUNNING`、`PREPARED=0`、owner PID不変、hardware
    pointer継続進行、`avail_max < buffer_size`を満たした。FCEUmm NES音声は合格。
    N64、headphone、他routeの同等確認が残るためA02全体はopenを維持する。
- [ ] `BUB-P4-A03` headphone 接続/抜去、ゲーム終了、suspend/resume 後の route 復帰を確認する。
- [ ] `BUB-P4-P01` backlight 0..255 の安全範囲、段階、persist policy を決める。
- [ ] `BUB-P4-P02` battery/charger node、capacity、charging状態、volume/power keyをhelperへ閉じ込める。
- [ ] `BUB-P4-P03` normal shutdown/reboot、charger接続前後、cold boot、suspend/resumeを実機確認する。
- [ ] `BUB-P4-P04` power action後にFAT/ext4がcleanであることを次boot/read-only fs checkで確認する。
  - terminal shutdown/rebootでp3/p4 clean markerを書いてsyncし、p4を明示unmountしてから
    p3をread-only化する実装を追加。marker作成/unmount順とclean fast bootはhost fixture合格、
    実機power actionと次bootでのmarker消費・fsck skip確認を残す。

### Network/USB/storage

- [ ] `BUB-P4-N01` AP6330 firmware/NVRAM/module/runtime ownership を固定する。
  - stock hash/vermagic固定の`bcmdhd.ko`、firmware、NVRAMをdevelopment seedへ隔離して組み込み済み。
  - 実機load/associationと再配布license判断は未完了。
- [ ] `BUB-P4-N02` first connect、credential persist、cold boot reconnect、Wi-Fi OFF persist、bounded recovery を確認する。
- [ ] `BUB-P4-N03` USB host/device/charging controller と同時利用制約を調査し、product policy を決める。
- [ ] `BUB-P4-S01` OS SD と ROM SD を UUID/label/partition identity で安全に解決する。
  - Bubble runtime inventoryで固定したsecondary controller `/dev/mmcblk3p1`だけを、
    OS `/storage` sourceとの非一致を確認して`/run/media/sd2`へread-only mountするhelperを追加。
    UUID/labelによる可搬なidentityと抜差し再mountは引き続き未完了。
- [ ] `BUB-P4-S02` dirty ROM SD を自動修復せず、警告・read-only・退避手順を定義する。
  - startup時のkernel filesystem errorをmanaged stateへ記録し、System Settingsへ表示する
    `plumos-storage-health observe`を追加した。手動checkはread-write mountを拒否し、
    FAT checkerがある場合も`-n`と120秒timeoutだけを使用する。実機表示確認を残す。
  - supervisorのgeneric `/storage` exportよりmounted SD2を優先し、scan後にもkernel errorを
    再観測する。これによりscan中に初めて現れるFAT errorも警告状態へ残す。
  - passive observeではdirtyをclean扱いに戻さず、complete indexがあるdirty媒体はboot scanを
    省略する。既存indexと警告を即時表示し、明示的なread-only checkだけが状態を更新する。

## P5: frontend and minimum game-path baseline

- [ ] `BUB-P5-01` Bubble 640x480 frontend profile と runtime DRM discovery を実装する。
  - CPU DRM、runtime connector/mode discovery、Bubble物理A/B mappingをhost build済み。
    `S39..E81`、input trace、frame statsを次のphysical gateへ組み込み済み。
  - SD2をROM rootにした際もmanaged app-layerのprimary/CJK fallback fontを優先し、
    日本語glyphをbuild時に検査するよう修正。日本語ファイル名が`???`にならず表示されることを
    利用者が実機確認済み。P5-01全体はDRM/page-flip gateが残るためopenを維持する。
- [ ] `BUB-P5-02` FEのinput、audio、brightness/volume、power menu ownershipをBubble helperへ接続する。
  - 共通STARTをUI / System / Network / Performance / Apps / Help / Reboot /
    Shutdownの8項目へ揃え、Bubbleで欠落していたPerformance導線を復元した。
    brightness、Wi-Fi、SSH、time/RTC、factory reset、safe reboot/shutdown helperを実装した。
    Rockchip DSIのbrightness/contrast/hue/saturation DRM propertyを実機で変更・readback・復元し、
    lumination/colorを実バックエンドへ接続した。PicoArch resetも既定envの復元へ接続した。
    FTP/SFTP/Sambaは分離stageで起動し、macOS clientから同一fileをreadback後に停止まで合格。
    lidはDT/input/interruptにsensorがなく、ADBはstock kernelがgadgetをmodule化している一方で
    対応module/UDCが存在しないため、虚偽の成功扱いにはせずhardware-blocked表示を維持する。
    System Updateは`/storage/user/updates`の署名済みRuntime packageを検証・予約し、安全再起動後に
    managed fileだけをjournal付きで適用する。DRM FE ready未確認の次bootでは全pathをrollbackし、
    active config/save/state/log/ROM/BIOS/credential/PortMaster installed stateを更新対象外にした。
    Ed25519署名、2回のapply/rollback、health確定、managed delete、設定保全をhost fixtureで確認。
    source `bdb7916`を実機へ反映し、署名packageの実機inspect/scan、全12,373 managed file hash、
    設定/SSH key不変、FE renderer-ready復帰を確認した。実packageのapply/rollbackはrelease候補で残す。
    NW情報がBusyBoxを解決できず全serviceを`Status Error`にしていたため、Bubble launcherから
    `/bin/busybox`を明示し、FEにも同pathのfallbackを追加した。source `6a72940`を実機へ反映し、
    SSH=スタート、FTP/SFTP/Samba=ストップ、ADB=利用不可、およびFTP起動時のスタートへの
    動的切替をtext rendererで確認した。表示とNW Serviceトグルは自動起動設定ではなく実processを
    基準にする。全12,373 managed file hashと既存service/system/frontend設定hashは不変・合格。
    Apps可視性監査ではA30/MF/MMF/V90S v2/XU20/Pixel2の現行sourceと計39 release tag、
    MF実機画面を照合した。Thumbnail Plan/Fetch/Resultsは全系列で実装済みだが非表示であり、
    Bubbleだけが表示していたためsource `a887dda`で非表示へ復元した。旧式settings/network catalog
    entryも他系列同様に非表示化し、内部実装とcoverageは保持。Bubble固有の設定rowは0件、STARTの
    各項目は他系列にも存在するため維持した。実機Apps 7項目、全12,373 managed file、設定hash、
    renderer-ready FE 1 processが合格。
    boot/kernel/DTB/System matching-setは正式A/B slot完成までfull-image更新として分離する。
    host contract/buildは合格。実LCDでの各画面、設定反映、reboot/shutdown後のclean mountを残す。
- [ ] `BUB-P5-03` Bubble向けRetroArchとQuickNESをpinned sourceからbuildしcomponent manifestを生成する。
  - RetroArch v1.22.2とQuickNES `058d665`をAArch64 containerからbuildし、
    software DRM/RGUI/ALSA/udev、GPU runtime非依存、component checksumをhost検証済み。
  - RGUIに加えてXMB/Ozoneをbuildし、pinned公式assetと日本語fontを同梱。既定RGUIは
    plain DRM、XMB/Ozone選択時はKMS/EGL/GLESを使用し、3 driverの実機初期化まで合格。
    利用者がCore Provided/整数scale、RGUI、XMB、Ozoneの物理LCD表示と操作を確認し合格。
- [ ] `BUB-P5-04` 利用者提供の小さな既知正常NES content 1本だけをGit外からtest deploymentする。
- [ ] `BUB-P5-05` FE -> QuickNES -> FE のdisplay/input/audio lifecycleを実機確認する。
  - RetroArchとPicoArchのQuickNESはcontent起動、ALSA pointer進行、停止後FE 1 process、
    audio owner解放まで合格。PicoArch QuickNESはLCD向き/aspect、speaker実聴、A/B、
    両Function menuとFE復帰を物理合格。RetroArch側の同等物理確認は別gateとして残す。
- [ ] `BUB-P5-06` menu/exit、save/state、reboot後の保持を確認する。
- [ ] `BUB-P5-07` game終了後にfrontendが1 processだけで、DRM/input/audio owner残留がないことを確認する。

## P6: wider runtime and compatibility

- [x] `BUB-P6-00` 利用者ROMセットをread-onlyで棚卸しし、ファイル内容を取り込まず
  top-level 33 directoryと共通plumOS catalogの対応境界を記録する。
  - 27 directoryは直接対応し、`ATARI`と`_etc`は複数systemを内包、`msx2`はMSXへ対応する。
    `bios`はgame scan対象外、`01`は他環境の管理tree、`3ds`は共通runtime未対応として扱う。
- [ ] `BUB-P6-01` MF v1.0.4 (`0095017`) の97 system / 196 launch profileを
  Bubble共通catalog baselineとして固定し、ROMセットのnested aliasを追加する。
  - 97 common systemに可視`3ds: unsupported`を加えた98 system、196 profile、
    `ATARI`/`_etc`/`msx2`のnested aliasをhost verifierで固定済み。実機一覧確認を残す。
- [ ] `BUB-P6-02` catalogの114 source core、116 RetroArch core id、alias binaryを
  pinned sourceからBubble用に再現buildし、全coreをcomponent manifestへ収録する。
  - software core 108件をplain DRM baselineへ接続し、GLES必須6件はBubble GPU runtimeへ隔離する。
  - 114/114 source recordをAArch64 buildし、全component checksum、実`dlopen`、
    必須libretro ABI、API v1検査に合格。Flycast XtremeのOpenMP linkと
    MBA Miniの欠落work queue/VBI objectをこのgateで修正した。Flycast Xtremeの
    `libgomp.so.1`もapp-layerへ同梱済み。全coreの実機content試験を残す。
- [ ] `BUB-P6-03` PicoArch 20 core id / 36導線、standalone 5導線、Pyxel、Portsを
  Bubble固有display/input/audio/session wrapperでcomponent化する。
  - PicoArch、PCSX-ReARMed、YabaSanshiro、PPSSPP、OpenBOR、Pyxel、PortMasterを
    host build/checksum済み。DraSticは項目を維持し、`/dev/miyooio`非搭載理由付きで
    visible unsupported。各runtimeの実機検証を残す。
  - PicoArchの欠落SDL2をcomponent内へ追加し、QuickNES contentと停止時child回収を実機確認。
  - PyxelはBubble Systemに無い`libdl.so.2`でimport前に失敗していた。互換DSOを
    component-scopedで同梱し、Pyxel 2.9.3のhost/device importまで合格。さらにBubble
    vendor MaliをEGL/GLESで統一したKMSDRM/ALSA経路で、正常な`.pyxapp`のDRM、PCM
    `RUNNING`、256x240から512x480への16:15表示契約まで実機合格。SD2上の2ファイルは
    CRC/zlib破損のため、媒体修復後のFE入力・終了復帰を残す。
    standalone YabaSanshiroもSaturn content、GLES、ALSA、正常終了に合格した。
  - OpenBORはgeneric SDL2 software rendererでKMSDRM surface生成に失敗していたため、
    Pyxel/PCSXと同じBubble SDL2 + Mali GLES2へ統一。DRM ownerとPCM `RUNNING`を実機合格。
  - renderer auditでPyxel/PortMaster GUIのMesa `kms_swrast` fallbackと、PortMaster portへの
    global software強制を除去。PFSを同一60fps設定で測定し、`ondemand`は28.74–29.16fps、
    `performance`は36.58–56.43fpsだった。全試行でMaliを使用しsoftware GL mappingはゼロ。
    Pyxelだけをgame中`performance`既定とし、終了時に元governorへ復元する。実LCD操作と
    PFS既存30fps設定を60へ戻した物理確認は未完了。
- [ ] `BUB-P6-04` package済みcoreからFE導線、FE導線からlauncher/coreを双方向検証し、
  実行不能な導線も`未実装`/`未対応`理由付きで表示する。QuickNES-only app-layerはreleaseを拒否する。
  - 98 system / 196 profile / RetroArch 116 id / PicoArch 20 id / standalone 5 idと
    visible app launcherをhostで双方向検証済み。app-layerは7 component必須、
    `all-114-source-records`以外を拒否し、`release_complete=false`/`publishable=false`を固定した。
  - STARTおよびAppsをA30/MF/MMF/V90S/XU20と再監査。Bubble独自項目は双方0件、Apps 10項目は
    MF/V90S v2と順序まで一致した。Scraping/thumbnail取得を共通実装へ置換し、File Managerと
    Music PlayerをBubbleのDRM/input/audio/SD2契約でbuildして全Apps導線を実装した。
    機械可読coverageとhost testは合格。各アプリの物理LCD/input/audio/終了復帰を残す。
- [ ] `BUB-P6-05` BIOS requirement、content extension、renderer、loader/library、license、
  save/state pathをcoreごとのmachine-readable coverage manifestへ固定する。
- [ ] `BUB-P6-06` PortMaster static audit、loader/env/session guard、代表runtimeの実機確認を行う。
- [ ] `BUB-P6-07` app/game終了時に同一sessionだけを回収し、frontend/device ownershipを復元する。
  - SSH benchmarkがfrontendを複数回停止してPID 1の4回restart limitへ到達した。`sync`後の
    強制rebootで通常FE 1 processへ復旧。今後の繰返し性能試験は通常FE導線を各試行で使うか、
    validation hold中にfrontend restart attemptを消費しない専用supervision契約が必要。
- [ ] `BUB-P6-08` 全system表示、全profile選択、全core load smoke、代表content起動をhostで通してから、
  ROMセットを変更せず一括実機acceptanceを開始する。
  - hostでは全system/profile解決と114/114 core load smokeまで合格。
    contentを使う代表起動、画面・入力・音声・終了復帰は正式partition imageで一括実機試験する。
  - 実機代表contentはNES/GBA/PS1/Dreamcast/Saturnのprocess・PCM進行に合格。
    N64はParaLLEl/Mupen64Plus-NextともPCMが`PREPARED`のままで未合格。
    PSP/NDSはROM SDにcontentがなく未試験。物理LCD/aspect/speaker確認を残す。
  - boot supervisorがSD2 pathをexportしない場合もfrontend launcherがread-only
    `/run/media/sd2`を自動選択するよう修正。SD2へdirectoryを作らず、実機再走査を検証する。
  - direct-root走査でROM SDのFATから`invalid start cluster`、`corrupted directory`を実機検出。
    自動fsckは行わず、scanを180秒で打ち切って既存indexを保全しFEを起動する。
    SDの退避・ホストfsck・再走査は利用者と媒体変更境界を確定してから行う。
  - volume persistent/runtime/softvolを全て0にして98 system / 196 profileを機械走査。
    clean contentの再試験を合算して89導線起動、BlueMSX 1導線失敗、DraStic 1導線visible
    unsupported、clean content不足またはexternal 105導線。未試験導線は削除していない。
    MSX標準は合格したfMSXへ変更し、BlueMSXも失敗理由付きで選択肢を維持する。
- [ ] `BUB-P6-09` Bubble全物理入力を実機captureから固定し、全runtimeへ割り当てて物理確認する。
  - event0/1/2、runtime DT、`JSIOCGBTNMAP`/`JSIOCGAXMAP`から、D-pad、ABXY、
    Select/Start、L/R/L2/R2、両stick/L3/R3、Function 2個、volume、powerを記録済み。
  - PicoArchのA/B逆転、L3/R3欠落、Function1欠落と、誤ったABS_Z/RZ trigger前提を修正した。
    全runtimeのmenuをFunction1/js17へ統一。RA screenshotはFunction2/js10へ移し、既存機能を
    保持。PicoArch/PCSX/YabaSanshiro/DraStic/SDL standaloneのmappingをbuild/deploy済み。
  - RetroArch factory/active cfgもD-pad button 13..16、L3/R3 11/12、right stick axes 2/3へ
    修正し、競合していたL2 hold-fast-forwardとR2 rewindを解除した。実機の全button確認を残す。
  - RGUIを閉じた直後のgame layer page-flip event欠落を実機で特定。plane切替後の最初の1 frameだけ
    blocking atomic commitにするbarrierと即時flush診断ログを追加。source `4e9e9fd`を
    RetroArch 110/110、app-layer 4978/4978でlive deployしたが、物理再試験では再発。
    barrierはmenu/gameとも完了後、main threadが`ppoll`で停止した。MF Patch 013が禁止する
    `DRM_MODE_ATOMIC_NONBLOCK`をBubble Patch 014で追加していた差分を特定し、MF同様の
    blocking atomic commit + completion eventへ戻したsource `6526d4c`を、RetroArch 110/110、
    app-layer 4978/4978でlive deployしたが再発。gdb backtraceで実停止箇所はDRMでなく
    `audio_driver_flush -> alsa_write -> snd_pcm_wait`と確定した。PCMは`RUNNING`表示のまま
    1秒以上hw/appl pointerが不変であり、vendor 4.19 RK817のpause解除後DMA停止を特定。
    menu開始をPCM drop、復帰をprepareへ変更したsource `afd8801`をRetroArch 110/110、
    app-layer 4978/4978でlive deploy済み。利用者がFCEUmm/NESで複数回menuを開閉し、hangせず、
    復帰後のゲーム音声とスクロールも正常であることを物理確認した。このresume regressionは
    合格とし、他core/runtimeへの一般化は`BUB-P6-10`で行わない。
  - PicoArch QuickNESのA/B、両Function menu、menu A決定/B戻る、FE復帰は物理合格。
  - standalone各機種固有layout、全runtimeの物理操作、menu/exit、system-owned volume/powerを残す。
- [ ] `BUB-P6-10` 全system/coreをdisplay分類し、向き・content/menu rotation・aspect・audioを実機確認する。
  - horizontal、vertical arcade、rotated handheld、square、wide、dual-screen、GLES経路を分離し、
    QuickNES一件の合格を他coreへ一般化しない。未試験導線はFEから消さず理由付きで維持する。
  - runtime logのframe/aspect/rotation/viewport/scanoutとPyxel fitを機械検査するverifierを追加。
    62 observed contractは全て640x480内・中央・回転後aspect一致。縦FBNeoはrotation 3、
    360x480+140+0で3:4を維持した。geometryを公開しないPicoArch/hardware core/standalone、
    dual-screen、clean content不足routeのLCD実見とspeaker実聴は未完了。

## P7: update, lifecycle and release

- [ ] `BUB-P7-01` signed package、downgrade拒否、System A/B、app-layer journal/rollbackを実装する。
  - Bubble RuntimeのEd25519署名、source/vendor/ABI照合、journal/rollback、FE ready health gateは実装・
    host fixture合格。version順序に基づくdowngrade拒否とboot/System A/Bを残す。
- [ ] `BUB-P7-02` boot/kernel/DTB/module/System matching-set updateとrecoveryを設計・実機検証する。
- [ ] `BUB-P7-03` normal、tamper、disk full、中断、bad slot、health failure、old version updateを試験する。
- [x] `BUB-P7-04` factory defaultとactive user configを分離し、update/factory reset policyを確定する。
  - Runtime update inventoryはfactory-defaultsと静的frontend/standalone configだけを管理し、active
    config/save/state/log/user media/credentialを除外。factory resetは明示選択されたcategoryだけ復元する。
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
- [ ] QuickNES単独の物理試験をここで打ち切り、正式partition provisioningを先に完成させる。
  その後、97-system catalog、全core、PicoArch/standalone/Pyxel/PortsとFE導線を一括packageし、
  host coverage gateに合格してからROM総合試験へ進む。
  - 全runtimeのhost build、98 system / 196 profileの導線検証、114/114 core load smoke、
    1.8 GiB app-layer checksumまで合格。first-boot p3拡張とp4生成もhost fixture合格。
    personalized full-stack validation imageのpartition/app-layer readbackも全合格し、旧imageを削除済み。
    実機first bootでp3=8 GiB拡張、p4作成は完了したが進捗画面は表示されなかった。
    代表contentのruntime結果は
    `docs/validation/2026-09-02-bubble-emulator-device-acceptance.md`へ記録した。
    次は物理LCD/aspect/speaker確認、N64 audio修正、visible first-boot progressを行う。
