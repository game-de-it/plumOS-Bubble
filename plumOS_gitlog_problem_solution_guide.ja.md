# plumOSシリーズ Git履歴から得られた問題・対策・新機種移植ガイド

作成日: 2026-09-01  
対象: `/Users/kroot/plumOS-*` 直下の6リポジトリ

## 1. この文書の目的

この文書は、plumOSシリーズのGit履歴を単なる変更一覧として読むのではなく、次の形へ
再構成したものです。

- どのような症状が発生したか
- 何を原因として切り分けたか
- どの境界を変更して解決したか
- その判断を別の新機種へどう再利用できるか
- どの確認を終えるまで「動作した」と言ってはいけないか

別のAIまたは開発者が新しいハンドヘルドへplumOSを移植するときの、調査順序、設計判断、
検証項目の基礎資料として使うことを想定しています。

重要な変更には、`リポジトリ名: コミット`の形式で参照を付けています。詳細は次のように
確認できます。

```sh
git -C /Users/kroot/plumOS-pixel2_v2 show 1f27134
```

## 2. 分析範囲

| リポジトリ | 到達可能コミット数 | 分析した期間 | 主な対象機種 |
|---|---:|---|---|
| `plumOS-A30` | 480 | 2026-06-06 - 2026-07-25 | Miyoo A30 |
| `plumOS-MF` | 381 | 2026-07-24 - 2026-08-24 | Miyoo Flip / RK3566 |
| `plumOS-MMF` | 132 | 2026-07-03 - 2026-07-25 | Miyoo Mini Flip |
| `plumOS-V90S_v2-public` | 350 | 2026-07-09 - 2026-08-26 | POWKIDDY V90S |
| `plumOS-XU20V32` | 187 | 2026-08-01 - 2026-08-24 | MagicX XU20 V32 |
| `plumOS-pixel2_v2` | 606 | 2026-08-11 - 2026-08-31 | GKD Pixel2 |

分析対象は、現在の`HEAD`から到達できる履歴、タグ、コミット本文、差分統計、および
コミットとともに追加された設計・検証文書です。`plumOS-MMF`は一部の過去Git objectが
欠損しており、`git rev-list --all`では全参照を完全に走査できません。このためMMFは、
現在の`HEAD`から到達できる132コミットと既存タグ・文書を基準にしています。

## 3. 結論: 問題はエミュレーターより境界で起きる

シリーズ全体で繰り返し発生した重大問題は、個別エミュレーターの機能不足よりも、次の
境界に集中しています。

| 境界 | 典型的な症状 | 根本対策 |
|---|---|---|
| StockOSとplumOSの所有権 | 起動しない、サービスが二重起動、終了後にFEが戻らない | 起動基盤とplumOS管理領域を明文化し、所有者を一つにする |
| boot/kernel/DTB | ロゴ停止、画面消失、入力・USB・Wi-Fi同時停止 | vendor実装を機能契約として扱い、差分を小さく実機bisectする |
| display/scanout | 黒画面、1操作遅れ、59/30fps、メニュー崩れ | 物理scanout、論理座標、page flip完了、回転を別々に検証する |
| input | 二重入力、無反応、誤ったA/B、終了不能 | 実eventを採取し、物理入力と仮想padの所有を一元化する |
| audio clock/router | 無音、復帰後無音、徐々にFPS低下 | ALSA ring、実sample rate、hotplug、suspend再初期化を管理する |
| runtime ABI | 起動直後停止、shellだけ暴走、別アプリが壊れる | componentごとにloaderとlibrary pathを隔離する |
| USB/Wi-Fi | ADBとWi-Fiの競合、cold bootだけ接続不可 | controller/OTG roleを一つのpolicyで調停し、機能を欲張らない |
| storage/update | ROM消失、古い設定へ戻る、半適用状態 | immutable/mutableを分離し、署名・atomic apply・rollbackを使う |
| release engineering | 開発機では作れるがcloneから作れない | 入力artifact、hash、license、生成手順を固定する |

新機種移植で最も重要なのは、既存機種のファイルを早くコピーすることではありません。
**stock環境が暗黙に担当している契約を、書き込み前に観測して一覧化すること**です。

## 4. 機種横断で得られた設計原則

### 4.1 StockOSは参考実装であり、同時にハードウェア契約である

StockOSのUIや古い設定をそのまま新仕様へ昇格させる必要はありません。一方で、boot prefix、
DTB、panel初期化、PMIC、vendor EGL、audio serverなどは、名前から判断して消してはいけない
機能契約である場合があります。

- A30はNAND/rootfsを書き換えず、SD上の`plumos/`へ所有物を集約しました。
- MFは直接initramfs起動を試したものの、実機は内部MTDから起動し続けたため、可逆な
  stock `.tmp_update` hookへ切り替えました。`plumOS-MF: 9223c85`
- Pixel2は独自に再生成したDTBではなく、最終的に正確なstock runtime DTBを復元しました。
  `plumOS-pixel2_v2: 1f27134`
- XU20は`CONFIG_IOMMU_DEBUG`のような「debug」という名前の設定が実際にはDMA attachを
  実行する機能条件だったため、vendor kernel baselineへ戻しました。
  `plumOS-XU20V32: 38daefd`

原則は、**stockを丸ごとコピーすることでも、stockを早く捨てることでもなく、契約を確認して
所有範囲を決めること**です。

### 4.2 物理表示と論理表示を分ける

表示問題は、次の層を混ぜると長期化します。

1. panelの実解像度・実refresh
2. framebuffer/DRM surfaceのstride・format・buffer数
3. EGL/GLESまたはvendor blitter
4. frontend/game/menuが使う論理座標
5. content rotationとmenu rotation
6. page flip完了と次buffer再利用の同期

V90Sではsysfsが60Hzを示していても、display interrupt実測は約59.06Hzでした。
`plumOS-V90S_v2-public: be4c81b`。MFではFPS表示が約60でもpage-flip完了を待たないため
scrollingが不均一でした。`plumOS-MF: 4ed77d6`。XU20ではPowerVR swapchainが提出した
frameを次回presentまで表示せず、「入力が1回遅れて反映される」ように見えました。
`plumOS-XU20V32: 1737092`。

したがって、FPS counterだけを表示合格の根拠にしてはいけません。framebuffer capture、
実機写真、割り込み周期、page-flip event、操作時の表示更新を組み合わせて判断します。

### 4.3 Threadingは性能問題を隠せるが、同期契約の代わりにはならない

threaded videoやnon-blocking submitは、平均FPSを上げられる一方で、buffer再利用、表示順、
入力からscanoutまでの待ちを増やすことがあります。MFのRetroArchではfixed panelに対して
DRM page-flip eventを待ち、完了後だけbufferを進める方式に修正しました。non-blocking atomic
commitは`EBUSY`を起こしたため、blocking commitとevent drainを採用しています。

新機種では「60fpsだから正常」ではなく、次を個別に測定します。

- coreがframeを生成した周期
- GPUへsubmitした周期
- page flipが完了した周期
- panel interrupt周期
- input eventからvisible frameまでの時間

### 4.4 入力は実機採取から始める

ボタン名、SDL mapping、evdev codeを他機種からコピーしないでください。A30では物理keyboard
deviceとjoystickd仮想padの両方をSDL1が読むことで二重入力が発生し、PicoArchを
joystick-onlyにしました。`plumOS-A30: d470485`。Pixel2では複数回の実機確認でA/B配線と
frontend identityを修正しています。XU20ではkernel側のsimplepad/UART threadもcontroller
crashの原因範囲でした。`plumOS-XU20V32: d63bdb8`

入力契約には最低限、通常ボタン、analog、lid、power、volume、function、hotkey、uinput、
exclusive grab、key-down/key-upの全対応を含めます。

### 4.5 Audioは「音が出た」だけでは合格しない

音声は、sample rate、ring occupancy、clock source、hotplug、fast-forward、suspend/resumeを
含む継続的な契約です。

- A30: sleep後にALSA PCM handleが再openされず無音になったため、RetroArchへ
  `AUDIO_REINIT` commandを追加。`plumOS-A30: e249f90`
- MF: USB DACが受けないrateを変換し、論理audioを48kHzへresample。
  `plumOS-MF: 13aabbf`
- MF: USB Audioの`snd_pcm_delay()`がALSA ring外のURB/FIFOまで含み、論理occupancyが
  過大になるため、ring sizeと`avail_update`からbounded occupancyを計算。
  `plumOS-MF: b5bd9a8`
- V90S: 上記修正を移植し、USB DAC使用中に約60fpsから57fpsへ徐々に落ちる症状を解消。
  `plumOS-V90S_v2-public: 70a93cf`
- MF: suspend復帰後、prepared PCMを再startし、さらに無音bufferを先に流してSDL streamを
  復帰。`plumOS-MF: 7d0d134`, `b1ed6e4`

短時間の起動試験だけでなく、5分以上の継続、DAC抜き差し、headphone、fast-forward、
suspend/resume、終了後のroute復帰を確認します。

### 4.6 `LD_LIBRARY_PATH`を全体へ流さない

MFではADB wrapperがexportしたnetwork-service用`LD_LIBRARY_PATH`をshell、frontend、
Music Playerが継承し、stock loaderと別glibcが混在しました。プロセス自体は動いているように
見えても、`pthread_create()`付近で停止し、input/ALSA descriptorを取得できませんでした。
componentごとの明示的dynamic loaderと、所有libraryだけを使うwrapperへ変更しています。
`plumOS-MF: 242d647`

PortMasterでも同じ問題が拡大します。Pixel2では第三者portが`LD_PRELOAD`や
`LD_LIBRARY_PATH`を置換しても、子processの`execve`直前にplumOS側の必要chainとsession IDを
復元する共通guardを実装しました。`plumOS-pixel2_v2: 8ad0606`

### 4.7 process ownershipを名前だけで判定しない

frontend、launcher、game、helper、GPTokeYB、audio daemon、network daemonが同時に存在する
環境では、`pkill`だけでは別sessionを殺したり、background childを残したりします。

- A30ではFTP/SambaがFEから`/dev/fb0` fdを継承し、複数ownerに見えました。daemon exec前に
  fdを閉じています。`plumOS-A30: a3bd51b`
- MFではPortMaster stop時の所有権をcanonicalizeしました。`plumOS-MF: f3be40c`
- Pixel2ではsession identityを子processへ強制継承し、foreground終了後に同一sessionだけを
  回収します。`plumOS-pixel2_v2: 8ad0606`
- Pixel2のGPTokeYB終了処理は、一般的な`pkill`互換だけではFE復帰を壊したため、対象と
  lifecycleを限定して修正しました。`plumOS-pixel2_v2: f86e4ce`

### 4.8 USB、Wi-Fi、ADB、充電は同じhardware resourceを奪い合う

USB portやOTG controllerが一つしかない機種では、機能一覧上すべて対応できても、同時利用
できるとは限りません。

Pixel2はADB device roleとUSB Wi-Fi host roleを何度も調停しましたが、最終的にはWi-Fiを
優先し、ADBを機能面・service・UI・build source・testから包括的に削除しました。
`plumOS-pixel2_v2: 21fba08`, `aa1f9a8`

これは機能削減ではなく、hardware境界を明確にする設計判断です。曖昧なdual-role自動化を
残すより、優先機能、排他条件、再列挙、charger検出を明示する方が安定します。

### 4.9 mutable user dataをfactory/runtimeと分ける

更新対象に含めるべきものと、利用者が保持すべきものをmanifest上で分けます。

保持対象の典型:

- ROM、BIOS、save、state
- network credential、SSH key
- frontend設定、active RetroArch設定
- PortMaster download、port固有save
- screenshot、music、video、cacheのうちユーザー所有と定義したもの

A30のcheat対応は、active RetroArch configを上書きせず、必要設定だけappend configで注入
しました。`plumOS-A30: 5994862`。XU20 app-layer deployもuser settingsを保持しました。
`plumOS-XU20V32: 95b0020`。Pixel2の初回storage provisioningでは、setup後にuser partitionを
隠さない修正が必要でした。`plumOS-pixel2_v2: f1cdb63`, `cf8e96f`

### 4.10 更新は署名、atomicity、rollback、downgrade防止を一組にする

「zipを上書きする」だけでは、電源断、部分展開、古いpayload、active slot metadata不整合に
耐えられません。

- MF: atomic live update、hook-only update、user media保全。
  `plumOS-MF: ddf1ae4`, `cf3c3c7`, `d2256b5`
- MMF: 旧full packageへ差分をoverlayするincremental packaging。ただしactive boot wrapperも
  payloadへ含める。`plumOS-MMF: c459d77`, `b4673b7`
- V90S: 署名付きtransactional updateとSystem A/B。
  `plumOS-V90S_v2-public: a0c4026`
- XU20: boot control、System/Kernel対応更新、rollback。
  `plumOS-XU20V32: 18c2a5b`, `a180ccd`
- Pixel2: 自動downgrade防止とslot metadataのatomic update。
  `plumOS-pixel2_v2: a20cd2b`, `d090e6f`

### 4.11 clean cloneから作れないreleaseは再現可能ではない

開発機にだけ残るvendor binary、cache、old SD extractを暗黙に使うと、同じcommitから同じ
releaseを作れません。

- V90Sはvendor/release inputをhash・license付きartifactとして固定し、clean cloneから
  imageを再生成可能にしました。`plumOS-V90S_v2-public: 0fd3628`
- XU20はV90S baseline、Tina kernel SDK、vendor runtime、boot templateを入力artifactとして
  明示し、source completeness gateを追加しました。`plumOS-XU20V32: abb09e3`
- MMFではfresh-SD packageからPython/Pyxel treeが欠落し、既存SDでは動くのに新規SDでは
  Pyxelが消える問題が発生しました。Python 3.14.6とPyxel 2.9.6を再現buildし、必須payload
  gateへ追加しました。`plumOS-MMF: 654b4d7`

## 5. 機種別の主な問題と対策

### 5.1 plumOS-A30

#### 基本アーキテクチャ

A30では本体NAND/rootfsを原則変更せず、SDカード上の`/mnt/SDCARD/plumos`にfrontend、
runtime、library、RetroArch、core、設定、logを集約しました。stock MainUIは最小wrapperから
plumOSへ制御を渡し、失敗時にstockへ戻れる構成です。

#### 重要問題

| 問題 | 原因 | 対策 | 重要コミット |
|---|---|---|---|
| mGBAがRA/PicoArch双方で起動しない | generated `version.c`とPOSIX `memory.c`がbuild sourceから欠落 | 必要sourceを復元し、PicoArchでplumOS libraryを優先 | `7d5f01c` |
| PicoArchで入力が二重になる | joystickd仮想padと物理keyboardをSDL1が同時取得 | joystick存在時はSDL keyboard pathを除外 | `d470485` |
| sleep復帰後にRetroArchだけ無音 | suspendしたALSA PCM handleが再openされない | RA network command `AUDIO_REINIT`を追加 | `e249f90` |
| network service起動後にfb0 ownerが複数に見える | FTP/SambaがFEの`/dev/fb0` fdを継承 | daemon exec前にdisplay fdを閉じる | `a3bd51b` |
| Wi-Fi OFFが再起動で戻る | runtime停止だけでpolicyを保存していない | `wifi_enabled`を永続化しboot rescueも尊重 | `4275df7` |
| cheat機能追加で利用者設定を壊す危険 | update packageがactive RA configを持つ | directoryだけ追加し必要値をappend configで適用 | `5994862` |

#### 新機種への教訓

- 最初にrollback-safeなentry pointを作る。
- stock libraryを全体へ流用せず、必要runtimeをcomponentとして所有する。
- virtual input daemonを導入する前に、物理eventとSDLの重複経路を確認する。
- suspendはprocess生存だけでなく、audio/display/inputの再初期化まで確認する。

### 5.2 plumOS-MF

#### 基本アーキテクチャ

MFはstock kernelと起動基盤を使い、`/mnt/SDCARD/.tmp_update/updater`からplumOSへ制御を
渡します。通常SDは単一FAT32で、追加partitionやNAND書き換えを前提にしません。

#### 重要問題

| 問題 | 原因 | 対策 | 重要コミット |
|---|---|---|---|
| byte-perfectなSD imageでもstockOSが起動する | native SD bootは内部loader変更を要求 | 可逆なstock hook方式へ移行 | `9223c85` |
| fresh bootがmutationで止まる | launcher/serviceが起動中にstock領域やownershipを変更 | boot前副作用を除去しownershipを固定 | `8934ba5` |
| appがCPUを使うがinput/audioを開かない | global `LD_LIBRARY_PATH`で別glibcとstock loaderが混在 | componentごとのloader/library pathへ隔離 | `242d647` |
| RetroArchは約60fpsでもscrollが不均一 | DRM atomic flip完了を待たず次bufferを使用 | page-flip eventを待ち、完了後だけbufferを進める | `4ed77d6` |
| USB DACでrate不一致やclock不整合 | hardware rateと論理rateを同一視 | 48kHzへresampleし、ring occupancyをbounded化 | `13aabbf`, `b5bd9a8` |
| terminal power action後にFATがdirty | frontend終了だけでFAT flush/cleanを保証しない | power finalizeでsync・unmount・FAT処理を実施 | `9f5ecff` |
| suspend復帰後にSDL音声が無音 | PCMはpreparedでもstreamへ再投入されない | PCM restartとprime buffer送出 | `7d0d134`, `b1ed6e4` |
| 未検証SD2 scanがbootを複雑化 | 他機種由来機能を先に持ち込んだ | unsupported pathを削除 | `2d2cce8` |

#### 新機種への教訓

- boot方式はSoCの一般論ではなく、実機ROM/loaderがどこを読むかで決める。
- FAT単一カードでは、power actionの最終段階をroot所有helperへ集約する。
- DRMはcommit成功だけでなくcompletion eventまでをbuffer ownershipとする。
- app/serviceごとにruntimeを閉じ、parent shellの環境を信用しない。

### 5.3 plumOS-MMF

#### 基本アーキテクチャ

MMFはA30設計を参考にしながら、SigmaStar系の画面、入力、音声、電源を専用backendへ
閉じ込めています。標準DRM/EGL経路を仮定せず、MI_GFX、evdev、MI_AOを扱う共通backendを
SDL1/SDL2利用runtimeへ提供しました。

#### 重要問題

| 問題 | 原因 | 対策 | 重要コミット |
|---|---|---|---|
| FEからPyxelを起動すると音だけ出て黒画面 | FE停止時のframebuffer clearでpanel seed stateを破壊 | Pyxel経路ではclearを避け、FE-only fast stopを使用 | `2fd22c6` |
| emulatorごとにdisplay/audio shimが増える | vendor APIとSDLの境界が共通化されていない | SDL非依存のMMF backend APIを作成 | `d560518` |
| FEが固定800MHzでbattery効率を失う | userspace固定policyを継承 | `ondemand`をFE baselineとしてlauncher全体へ展開 | `0989294` |
| USB給電で通常OSまで起動する | power-off中のUSB挿入で自動power-onする機種仕様 | frontend前にstatic charging-only gateを実行 | `f0e11c1` |
| update後も古いboot wrapperがactive | payloadのbootstrapだけ更新し実entryを更新していない | `miyoo*/app/MainUI`もupdate payloadへ含める | `b4673b7` |
| fresh-SDでPython/Pyxelが消える | known-good SDにだけ存在するruntimeがrelease入力から漏れた | Python/Pyxelを再現buildし必須gateへ追加 | `654b4d7` |
| shutdown savestateとslot設定が不整合 | state保存後にRAを強制終了 | NetCMD `QUIT`で通常cleanupを待つ | `69f4370` |

#### 新機種への教訓

- vendor displayは、画面をclearするだけでもboot時seedやscanout ownershipを壊し得る。
- emulator別patchより、device backendを一層作る方が長期的に安全である。
- release packageは既存SDとの差ではなく、空SDから必要機能を再構成できるかで検査する。
- update対象は「source上のcanonical file」ではなく、「boot時に実際にexecされるactive file」まで
  追跡する。

### 5.4 plumOS-V90S

#### 基本アーキテクチャ

V90SはStockOS由来boot/kernelとPowerVR GE8300 runtimeを保持し、p3 ext4 runtimeとp4 FAT32
user volume上でplumOSを管理します。V90Sの開発では、Armbian風独立環境を先に作るより、
実機で動くKNULLI/StockOS hardware runtimeを特定し、その境界へplumOSを接続する方向へ
切り替えました。

#### 重要問題

| 問題 | 原因 | 対策 | 重要コミット |
|---|---|---|---|
| FPSが59.05付近で固定 | panel timingが実際に約59.06Hz | interruptとDTS timingを実測し、refresh調整を設計 | `be4c81b` |
| frontend brightnessが不安定 | generic制御がStockOS panel契約と不一致 | StockOS backlight制御を正式backend化 | `eadf55c` |
| USB Wi-Fi再挿入後に戻らない | module/device復帰とwpa/DHCP再構成が分離 | ueventからbounded recoveryを実行 | `63b2eda` |
| USB DAC使用中にFPSが徐々に57へ低下 | `snd_pcm_delay()`がALSA ring外までoccupancyに含める | `buffer_size - avail_update`へ変更 | `70a93cf` |
| update中断でSystemが半適用になる危険 | copy-over更新にtransaction境界がない | 署名、A/B、health、rollbackを持つ更新へ変更 | `a0c4026` |
| clean cloneでrelease imageを再現できない | vendor inputが開発機/旧SDにのみ存在 | hash・license付きrelease inputを固定 | `0fd3628` |

#### 新機種への教訓

- `fb0/modes`の`60`表記を信用せず、display interruptまたはpage-flip周期を測る。
- vendor backlight、codec、PowerVRは独自仕様を抽象化してからUIへ接続する。
- hotplug recoveryは無限watchdogではなく、event、timeout、再試行回数を持つ。
- audio clock不具合は、CPU負荷ではなく長時間のFPS driftとして現れることがある。

### 5.5 plumOS-XU20 V32

#### 基本アーキテクチャ

XU20はAllwinner A133 Plus、vendor boot chain、Linux 4.9.191、PowerVR runtimeをhardware
境界として保持し、4partition構成とSystem A/Bを採用しました。Tina/OpenWrt desktop
userspaceをそのまま製品にせず、必要なkernel/module/firmware/vendor runtimeを抽出しています。

#### 重要問題

| 問題 | 原因 | 対策 | 重要コミット |
|---|---|---|---|
| 初期移植で画面更新とcontrollerが不安定 | framebuffer refreshとsimplepad UART threadの機種差 | refresh helperとkernel patchを分離実装 | `d63bdb8` |
| NextCommander/PortMasterが1操作遅れて見える | PowerVR swapchainが次presentまでframeを表示しない | changed sceneを次の既存iterationでもう一度present | `1737092` |
| kernel debug削減後にinput/ADB/Wi-Fiが同時停止 | `IOMMU_DEBUG`等がvendor treeでは実機能をguard | 全削減を棄却しvendor baselineを復元 | `38daefd` |
| updateでkernel/System対応が崩れる危険 | kernel、module、DTB、Systemを別々に扱う | matching manifest付きSystem+Kernel update | `a180ccd` |
| USB給電で通常bootしてしまう | power reasonとcharge-only policyがbootloaderにない | redundant boot controlとU-Boot charge mode | `a9dd955` |
| USB DAC routeがwedgedし別coreへ影響 | 壊れたphysical routeを通常fallbackへ戻していた | 異常routeをquarantineし再利用を防止 | `27d3ffa` |
| releaseがV90S開発treeやlocal SDKに依存 | 入力artifactとsource completenessが未定義 | self-contained release inputsとgateを追加 | `abb09e3` |

#### 新機種への教訓

- vendor Kconfig名を意味で分類せず、preprocessor使用箇所とdisassemblyを確認する。
- kernel最適化は1symbolまたは小群で行い、長時間のG2D/VE/IOMMU stressまで見る。
- 「一度bootした」はkernel acceptanceではない。入力、USB、Wi-Fi、brightness、video decodeを
  同時に長時間動かす。
- PowerVR系ではdraw/present/visibleの境界が一致しない場合がある。

### 5.6 plumOS Pixel2

#### 基本アーキテクチャ

Pixel2はRK3326Sとstock boot substrateを保持し、stock initramfsが`SYSTEM`へhand offした後を
plumOSが所有します。初回bootでSystem領域を拡張し、FAT32`PLUMOS_USER`を作成します。

#### 重要問題

| 問題 | 原因 | 対策 | 重要コミット |
|---|---|---|---|
| 独自DTB経路でhardware回帰 | stockとの差分を安全に説明できない | exact stock runtime DTBへ戻す | `1f27134` |
| 初回provision後にuser partitionが見えない | setup marker/mount順がpartitionをmask | first-boot initとmount条件を修正 | `f1cdb63`, `cf8e96f` |
| ADBとUSB Wi-Fiが互いを壊す | 単一dual-role OTG controllerの所有競合 | 一時はexclusive mode、その後ADBを廃止しWi-Fi優先 | `21fba08`, `aa1f9a8` |
| plugged shutdownで通常再起動する | PMIC/chargerがpoweroffをbootへ戻す | kernel charge rebootとcharge modeを採用 | `014bd31`, `7bb4bdd` |
| aspect変更後に画面surfaceが古い | DRM surface geometryを動的に作り直していない | aspect変更時にsurfaceをrecreate | `6777ec6` |
| 第三者portがlibrary/preload/sessionを壊す | port scriptが環境変数を上書き | static audit、exec guard、session cleanup | `e56af80`, `8ad0606`, `6d7335b` |
| PortMaster終了後にFEが戻らない | GPTokeYB cleanupがprocess ownershipを越える | targeted `pkill` shimとsession検査 | `f86e4ce` |
| 古いupdateが自動適用される | version比較とslot metadata更新が弱い | downgrade拒否とatomic metadata | `a20cd2b`, `d090e6f` |

#### 新機種への教訓

- stock boot prefix、kernel、initramfs、DTBのうち、どこまで保持するかを最初に決める。
- 1つの物理portへhost/device/chargingを同時に期待しない。
- content rotationとmenu rotationは別stateにする。
- PortMaster互換はport名別patchより、ELF依存、環境、process ownershipの共通層で扱う。

## 6. 新機種へplumOSを移植する推奨手順

### Phase 0: 書き込み前の安全確保

1. stock mediaをsector単位でimage化し、SHA-256と容量を記録する。
2. partition table、unpartitioned prefix、filesystem、dirty flagをread-onlyで調べる。
3. ROM、BIOS、save、credentialを含むsource cardへ修復・resize・writeしない。
4. 実験は複製cardで行い、復旧手順を先に実行して確認する。
5. USB/ADB/SSHが無い場合のserial consoleまたはログ回収経路を準備する。

成果物:

- stock image hash
- partition/LBA map
- boot artifact hash一覧
- recovery手順
- write禁止領域一覧

### Phase 1: boot chainと所有権を確定

次を順番に証明します。

```text
Boot ROM -> SPL/U-Boot -> kernel -> initramfs -> System/rootfs -> launcher -> frontend
```

各段階について、保存場所、format、署名、fallback、writableかどうかを記録します。その後、
次のいずれかを選びます。

- stock hook型: boot/kernelはstock、launcher手前でplumOSへ渡す
- stock substrate型: boot prefix/kernel/initramfsを保持し、System以降をplumOS化
- plumOS boot型: kernel/DTBを含めて所有。ただしfull rollbackと実機検証が必要

この段階ではfrontend機能を増やしません。boot成功marker、画面単色、log、shutdownだけで十分です。

### Phase 2: hardware inventoryと最小probe

最低限採取するもの:

```sh
uname -a
cat /proc/cmdline
cat /proc/cpuinfo
cat /proc/meminfo
mount
cat /proc/bus/input/devices
ls -l /dev/fb* /dev/dri /dev/mali* /dev/input /dev/snd 2>/dev/null
cat /proc/asound/cards 2>/dev/null
ps w
```

さらにstock FE、RetroArch、standalone emulator動作中の`/proc/<pid>/fd`、`maps`、`environ`、
`cmdline`を取得します。小さなprobeを個別に作り、次の順に通します。

1. display geometry/color/stride/rotation
2. input event表
3. speaker/headphone/DACとsample rate
4. Wi-Fi/USB role
5. brightness/battery/charging/power key
6. suspend/resume

### Phase 3: 最小game path

最初の合格対象は1 system、1 core、1 ROM形式に限定します。

確認項目:

- FE停止とdisplay ownership handoff
- game画面の向き、aspect、色
- A/B/D-pad、menu、exit
- audio開始と継続
- save/state
- game終了後にFEが1processだけ復帰

この段階では大量core、PortMaster、scraper、network serviceを同時に導入しません。

### Phase 4: runtime isolation

componentごとに次を固定します。

- executableとarchitecture
- dynamic loader
- owned library directory
- `LD_LIBRARY_PATH` / `LD_PRELOAD`
- writable HOME/cache/config
- device node ownership
- child process/session ownership
- cleanup timeoutとfallback

global環境変数で「全部動かす」設計は避けます。

### Phase 5: lifecycleとpower

通常起動以外を独立試験します。

- warm reboot / cold boot
- normal shutdown / charger connected shutdown
- charger before sleep / charger after sleep
- suspend/resume中のaudio、display、Wi-Fi
- lid/power/volume/brightness hotkey
- FAT/ext4のclean shutdown

充電中の期待動作は、通常boot、charge-only、screen offのどれかを製品仕様として明示します。

### Phase 6: storageとupdate

partitionごとにownerを定義します。

| 種類 | 例 | 更新方針 |
|---|---|---|
| immutable boot | boot prefix、U-Boot、kernel、DTB | 署名、matching set、rollback必須 |
| immutable System | rootfs、managed binaries | A/Bまたはatomic replace |
| managed runtime | FE、emulator、service | manifestとhealth check |
| mutable config | active settings、credential | mergeまたは対象keyだけ変更 |
| user media | ROM、BIOS、save、screenshot | update対象外 |

update試験は、正常適用だけでなく次を含めます。

- payload改ざん
- version downgrade
- disk不足
- 適用途中の電源断を模した中断
- active slot破損
- health失敗からrollback
- 旧公開versionからのcumulative update

### Phase 7: release acceptance

release候補は次の順で確認します。

1. clean cloneからbuild
2. archive/image integrityとSHA-256
3. license、ROM/BIOS/secret混入検査
4. SDへwriteしてreadback
5. cold boot
6. update/rollback
7. 実機の画面、入力、音声、終了、save
8. sleep、charge、network、shutdown
9. 公開assetを再downloadしてchecksum確認

build成功、archive展開成功、launcher起動だけではrelease acceptanceになりません。

## 7. 新機種向け最小受け入れマトリクス

| 領域 | 最低限の実機確認 |
|---|---|
| Boot | cold boot 3回、warm reboot、失敗slot rollback |
| Display | FE、RA menu、game、standalone、rotation、aspect、色、frame pacing |
| Input | 全物理button、長押し、同時押し、menu、exit、hotkey競合 |
| Audio | speaker、headphone、USB DAC、5分継続、fast-forward、resume |
| Storage | ROM scan、save/state、dirty media、容量拡張、SD2がある場合の抜き差し |
| Network | 初回接続、cold boot復帰、OFF永続、dongle再挿入、service停止 |
| Power | shutdown、reboot、sleep、charger前後、brightness/volume保持 |
| Update | 正常、改ざん、downgrade、rollback、旧versionからの更新 |
| Apps | Pyxel、File Manager、Music Player、代表PortMaster runtime |
| Cleanup | game/app終了後にFEが1つ、mount/process/device owner残留なし |

## 8. 避けるべきアンチパターン

### 8.1 既存の動作中SDをそのままrelease原本にする

動作中SDにはcredential、save、cache、手作業修正、download済みPortMasterが混ざります。
immutable componentだけをmanifest/hashで昇格し、factory sourceから再構成してください。

### 8.2 他機種の設定を一括コピーする

画面解像度、rotation、button code、ALSA card、brightness polarity、USB roleは機種固有です。
既存機種は設計例として使い、値は必ず実機採取します。

### 8.3 `DEBUG`という名前だけでkernel optionを削除する

vendor treeではdebug optionが初期化処理をguardしている場合があります。source、preprocessor、
object disassembly、DTB clientを確認し、1変更ずつphysical bisectします。

### 8.4 global `LD_LIBRARY_PATH`で依存を解決する

一つのappが動いても、shell、frontend、service、別glibcを壊します。loaderとlibrary pathは
component所有にします。

### 8.5 FPS counterだけで表示性能を判断する

core FPS、render FPS、present FPS、panel refreshは別です。scrolling、input-to-photon、
page-flip event、interruptを確認します。

### 8.6 `pkill <name>`だけで終了処理を作る

PID再利用、別session、background child、helper残留を扱えません。process groupとsession IDを
使い、signal直前にもidentityを再確認します。

### 8.7 active config全体をupdateで置き換える

必要keyだけmerge/appendし、利用者の変更を保持します。factory reset用defaultとactive configを
別fileにします。

### 8.8 host testを実機合格とみなす

hash、syntax、unit testは必要ですが、panel、speaker、charger、controller、Wi-Fi、sleepを
証明しません。実機観測を別のacceptance gateとして残します。

## 9. 特に参照価値の高いコミット一覧

| テーマ | リポジトリ | コミット | 要点 |
|---|---|---|---|
| rollback-safe boot | A30 | `a78409d` | MainUI bootstrapを可逆化 |
| core build ABI | A30 | `7d5f01c` | mGBA生成source欠落を修正 |
| duplicate input | A30 | `d470485` | 仮想padと物理keyboardを分離 |
| sleep audio | A30 | `e249f90` | RA audio再初期化command |
| user config preservation | A30 | `5994862` | cheat追加でactive cfgを上書きしない |
| stock hook | MF | `9223c85` | direct bootから可逆hookへ転換 |
| runtime isolation | MF | `242d647` | loader/library pathをcomponent化 |
| DRM pacing | MF | `4ed77d6` | page-flip completionで同期 |
| FAT-safe power | MF | `9f5ecff` | shutdown前のstorage finalize |
| vendor backend | MMF | `d560518` | SDL非依存device backend |
| Pyxel black screen | MMF | `2fd22c6` | panel seedを壊すclearを回避 |
| charging boot | MMF | `f0e11c1` | frontend前のcharge-only gate |
| fresh release completeness | MMF | `654b4d7` | Python/Pyxel欠落を再現buildで修復 |
| real panel refresh | V90S | `be4c81b` | 59.06Hzをinterruptで証明 |
| transactional update | V90S | `a0c4026` | 署名・A/B・rollback |
| stock backlight | V90S | `eadf55c` | vendor制御をbackend化 |
| audio/FPS drift | V90S | `70a93cf` | ALSA ring occupancyをbounded化 |
| PowerVR present latency | XU20 | `1737092` | 次iterationの追加present |
| kernel false-debug dependency | XU20 | `38daefd` | vendor baseline復元 |
| System+Kernel update | XU20 | `a180ccd` | matching artifact更新 |
| charge-only boot | XU20 | `a9dd955` | U-Boot power reason policy |
| exact stock DTB | Pixel2 | `1f27134` | 再生成DTBを廃止 |
| first boot storage | Pixel2 | `f1cdb63` | System拡張とuser partition作成 |
| USB ownership decision | Pixel2 | `aa1f9a8` | ADBを廃止しWi-Fi優先 |
| PortMaster exec guard | Pixel2 | `8ad0606` | 子process環境とsessionを復元 |
| PortMaster cleanup | Pixel2 | `f86e4ce` | GPTokeYB終了後のFE復帰 |

## 10. 別のAIへ渡す実務上の指示

新機種で作業するAIは、最初の依頼が「plumOSを動かして」であっても、直ちに既存packageを
書き込まないでください。最初の成果物はコードではなく、次の5点です。

1. boot/partition/hardware inventory
2. stock processとdevice ownership表
3. preserved/replaced/unknownの境界表
4. 最小probe計画
5. rollbackと実機acceptance計画

実装開始後も、各変更を次の形式で記録すると履歴が再利用しやすくなります。

```text
Context:
  実機で観測した症状と、どの条件で再現したか

Cause:
  推測ではなく、log、source、counter、hash、A/B testで絞った原因

Changed:
  所有境界のどこを変更したか

Preserved:
  ROM、save、credential、stock artifactなど変更しなかった範囲

Verified:
  host test、package検査、deploy/readback、実機操作を分けて記載

Remaining:
  未確認のaudio、display、menu、exit、save、sleepなど
```

plumOSシリーズの履歴で最も再利用価値が高いのは、成功した最終ファイルそのものではなく、
**暗黙のhardware契約を発見し、所有境界へ変換し、実機で閉じるまでの手順**です。
