# plumOS Bubble 開発者ガイド

この文書は、GKD Bubble向けplumOSのbuild、変更、検証、release準備を行う人向けです。
利用者操作は[取扱説明書](../user/README.ja.md)へ分離しています。

## リポジトリの境界

- `rootfs/bubble-frontend/`: read-only System rootfsのoverlay
- `package/frontend-bubble/`: frontend、launcher、service、factory default
- `configs/bubble-controller-map.json`: 物理入力のcanonical map
- `configs/bubble-runtime-coverage.tsv`: runtime coverageと公開状態
- `scripts/build-bubble-frontend-system.sh`: System build
- `scripts/build-bubble-external-initramfs.sh`: external initramfs build
- `scripts/build-bubble-app-layer.sh`: managed app-layer build
- `scripts/build-bubble-frontend-probe-image.sh`: full raw image buildと統合gate
- `tests/`: contract、content、runtime、image verifier
- `docs/validation/`: host／実機のevidence。推測で結果を書き換えない
- `docs/decisions/`: product/release boundaryの決定記録

`package/frontend-bubble/plumos/config/frontend/systems.json`が公開system、ROM alias、
extension、launch profileのsource of truthです。利用者向け一覧は次で再生成します。

```sh
python3 scripts/generate-bubble-supported-systems-doc.py
python3 scripts/generate-bubble-supported-systems-doc.py --check
```

一覧からsystemを削除して問題を隠さず、実行経路または機種固有のunsupported理由を
coverageとFEへ残します。

## ownership

| 領域 | ownership |
| --- | --- |
| boot / vendor kernel / approved firmware | vendor由来。hashとNOTICEを固定 |
| System | read-only matching set、A/B更新対象 |
| `/mnt/plumos` app-layer | manifestと`checksums.sha256`で管理 |
| `/storage` | 利用者所有。ROM、BIOS、save、設定を保全 |
| SD2 | 任意のROM／BIOS source。電源中hot plug非対応 |

利用者設定やPortMaster更新物をapp-layer metadataへ合わせる目的で上書きしません。

## build

Docker tool imageと承認済みvendor inputを用意し、versionを明示して実行します。

```sh
PLUMOS_BUBBLE_VERSION=<version> \
PLUMOS_BUBBLE_INCLUDE_CAPTURED_VENDOR_GPU=1 \
./scripts/build-bubble-frontend-probe-image.sh
```

top-level scriptはSystem、initramfs、app-layerをbuildしてからraw imageを生成します。
成果物は`output/image/bubble-frontend-probe/`へ置かれ、Git管理しません。再現buildでは
clean clone、固定commit、`SOURCE_DATE_EPOCH`、artifact SHA-256を記録します。

## frontendとemulator lifecycle

ゲームはfrontendの正規経路から起動します。launcherはFEにdisplay/input/audioを解放
させ、child process groupを監督し、終了後に一つのFEだけを復帰させます。

FEとemulator／diagnostic rendererを同時に`/dev/fb0`または`/dev/dri/card*`へ描画させては
いけません。`SIGSTOP`はdisplay releaseではありません。これはflickerとLCD image
retentionを避ける必須boundaryです。

live deployで`/mnt/plumos`を更新する場合はcomponent単位でbinary、manifest、checksumを
揃え、実機上でSHA-256とapp-layer checksumを確認してから再起動します。

## 入力contract

- Function 1: evdev 704 / js17、本体前面、emulator menu
- Function 2: evdev 316 / js10、本体上部、RetroArch screenshot
- SELECT: js8
- START: js9
- RetroArch exit: SELECT + START

入力変更後は最低限、次を実行します。

```sh
sh tests/test-bubble-physical-input-contract.sh
sh tests/test-bubble-start-menu-contract.sh
```

## 主な検証

```sh
python3 tests/test-bubble-supported-systems-doc.py
python3 tests/test-bubble-documentation.py
sh tests/test-bubble-runtime-coverage.sh
sh tests/test-bubble-release-content-audit.sh
python3 scripts/verify-bubble-frontend-probe-image.py \
  output/image/bubble-frontend-probe/<image>.img
```

個別testのpassはrelease acceptanceの代わりになりません。新規SDへのwrite/readback、cold
boot、warm reboot、Wi-Fi、shutdown、sleep、audio、SD2、代表runtime、rollbackを物理的に
確認し、commitとimage hashへ紐付けます。

## update

[runtime update設計](../plumos-bubble-runtime-update.md)を参照してください。署名、device、
base version、payload checksumをfail-closedで検証し、同一versionとdowngradeを拒否します。
writer停止やread-only化に失敗した状態でreboot／shutdownを強行しません。

## licenseと公開

plumOS独自部分はMITです。stockOS由来物はGKDの所有物で、vendor runtimeとDraSticには
repositoryのNOTICEとallowlistが適用されます。法的文書、provenance、binary inventory、
ROM／BIOS／credential／private-key scanをrelease artifactごとに保持します。

artifact生成と公開は別操作です。release candidateを利用者が確認し、明示的に公開を
承認するまでGitHub releaseを作成しません。公開後は匿名経路でassetを再取得し、公開
checksumと一致することを確認します。

## 現在の物理確認上の制約

2026-09-11時点で対象実機の本体上部SYSスロットが故障しています。これ以前に得た各機能
の実機evidenceは有効ですが、最後に再buildしたimageそのものの新規write/readback、cold
boot反復、最終acceptanceは実施できません。この制約をrelease noteで明示し、host検査を
物理確認済みと表現しないでください。

詳細は[最終候補とSYSスロット制約](../validation/2026-09-11-bubble-final-candidate-hardware-limit.md)
および[release candidate image検証](../validation/2026-09-11-bubble-release-candidate-image.md)
を参照してください。
