# Bubble TODO completion audit (2026-09-09)

## Scope and rule

`TODO.md`のunchecked項目を、現source、過去のhost/device evidence、clean image、起動中実機の
read-only inventoryに対して再照合した。文書だけ、hostだけ、process存在だけを物理acceptanceへ
読み替えない。媒体書込み、意図的破損、周辺機器操作、license判断、release公開は自動完了扱いに
しない。

監査前は103項目中21完了/82未完了だった。実装・検証済みなのに古いままだった46項目を閉じ、
67完了/36 openへ更新した。残る36件は
`configs/bubble-todo-open-gates.json`へ分類し、`scripts/audit-bubble-todo.py`がTODOとの双方向一致を
検査する。匿名unchecked、分類漏れ、完了済みIDのstale分類はtest failureになる。

## Mechanical verification

- repository test: `tests/test-*` 33/33 pass（監査test追加前）
- macOS bash 3.2: first-boot storage/start-menu contract pass
- emulator catalog: 98 systems、196 profiles、114/114 source core load smoke
- GGFE artwork: PNG/JPEG/WebP decoder fixture pass
- frontend: AArch64 build、component checksum、GL非リンク、JPEG/WebP runtime DSO/license収録 pass
- clean full-stack image: partition/System A/B/component/catalog verifier pass、
  `personalized=no`、`release_complete=no`、`publishable=no`

`release_complete=no`は失敗の隠蔽ではない。captured vendor artifactの再配布判断と、物理acceptance、
fault injection、利用者の公開承認が残るため、private hardware-validation imageをreleaseへ昇格させない
意図したgateである。

## Live read-only inventory

起動中実機 `192.168.10.101` は次の状態だった。

- display ownerは`plumos-controller-ui-fbdev` 1 processだけ。emulator/GGFE/PortMasterは0。
- DSI connectorはconnected、modeは640x480。
- p1 `/flash`はread-only、p3 `/storage`、p4 `/storage/user`はread-write。
- SD2 `/dev/mmcblk3p1`は`/run/media/sd2`へread-write mountされ、Roms/BIOS bindもread-write。
- FTP 21、SSH/SFTP 22、Samba 445がlisten。
- inputはpower `event0`、gpio keys `event1`、retrogame joypad `event2/js0`、G-sensor
  `event3/js5`。

この採取では画面ownerを変更しておらず、FEと別rendererを同時実行していない。

## Remaining gate classes

残る項目は次の種類だけである。正確なIDと分類はmachine-readable JSONを正とする。

| class | 必要なもの |
|---|---|
| offline-media / recovery-hardware | SDを停止・接続してのsector readback、filesystem read-only check、known-good交換 |
| boot-probe / timing-hardware | U-Boot active environment/UART、warm boot、milestone計測 |
| destructive-fault-injection | checksum破損、disk-full、中断、bad slot、health failureをrollback付きで意図的に発生 |
| display-instrumentation | CRTC/plane/format/stride/modifier、page-flip継続、input-to-visible計測 |
| physical-input/audio/power/network/USB | 全ボタン、headphone/jack、5分XRUN、charger/suspend、Wi-Fi OFF保持、USB policy |
| storage-identity | SD1/SD2のUUID/labelを使うhotplug-safeな解決と実機抜差し |
| coverage/runtime | core別license/save/stateを含むcoverage完成、PortMaster代表runtime、残る全routeの実LCD/音声 |
| update/release | downgrade拒否、boot matching-set recovery、3 cold boot、RC acceptance、license/source gate |
| release-approval | 利用者の明示的なrelease承認と公開asset再取得 |

## Interpretation

sourceと現在接続中実機へ安全に自動実行できるTODOは閉じた。残る36件を`[x]`へ変えるには、
媒体の取り外し、物理操作/周辺機器、破壊試験、法的判断、または明示的なrelease承認のいずれかが
必要である。これらを証拠なしに完了扱いにすることは、`TODO.md`先頭のacceptance ruleと
移植ガイドの「host testを実機合格とみなさない」に反する。
