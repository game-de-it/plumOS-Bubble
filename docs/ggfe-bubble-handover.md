# GGFE Bubble実装・動作試験 引き継ぎ

この文書はGGFEをBubble実機で動かし、受け入れ試験を行うための引き継ぎである。
GGFEの仕様そのものは `docs/ggfe.md`（操作・設定・解決規則・移植）を参照する。

## 1. 位置づけ

GGFEはGame Gear専用のフロントエンドで、カートリッジをCPU software 3Dで描画し、
選択したゲームを通常のplumOS起動経路へ渡す。

**`plumos-controller-ui` とは別バイナリである。** 共通plumOSメニュー項目は一切変更して
いない。GGFEはAppsの1項目として追加され、既存FEは `shell:` アプリ実行前にrendererを
落とすため、`plumos_controller_ui.c` は無改変でDRM handoffが成立する。

GLもEGLも `/dev/mali0` も使わない。RetroArchとGPU/DRM masterを奪い合わないことが
設計の前提であり、`scripts/build-bubble-frontend.sh` が
`libEGL|libGLESv2|libgbm|libmali` のリンクを検出したらビルドを落とす。

### 構成ファイル

| 種別 | パス |
|---|---|
| ラスタライザ | `src/frontend/plumos_cart3d.h` |
| カート/ケース形状 | `src/frontend/plumos_ggfe_model.h` |
| 設定・サムネ解決・ROM走査 | `src/frontend/plumos_ggfe_art.h` |
| 起動プロファイル解決 | `src/frontend/plumos_ggfe_launch.h` |
| 本体 | `src/frontend/plumos_ggfe.c` |
| 共有ヘッダ | `src/frontend/plumos_json.h`, `plumos_path.h` |
| 起動スクリプト | `package/frontend-bubble/plumos/bin/plumos-ggfe-launch` |
| 設定 | `package/frontend-bubble/plumos/config/frontend/ggfe.json` |
| テーマ資産 | `package/frontend-bubble/plumos/themes/default/ggfe/` |

`plumos_json.h` と `plumos_path.h` は `plumos_library_scan.c` から**逐語コピーで抽出**した。
サムネ解決を独自実装すると既存FEと解釈がズレるため、同一コードを使っている。
`plumos_library_scan.c` 側の重複コピー削除はTODO.mdに分離して記載済み。

## 2. 現状（検証済みと未検証を厳密に分ける）

### ホスト側で検証済み

- 実機ビルドがAArch64で通り、GL stack非リンクのgateを通過する
- frontendフルビルドが `bubble_frontend=result-ok`、checksums/manifestに登載される
- サムネ解決が参照実装（`find_thumbnail()`）と全規則で一致する
- 起動プロファイル解決チェーンが設計どおり動く
  （`tests/test-bubble-ggfe-launch-resolution.sh`）
- ASan/UBSanクリーン
- emulator catalog gate、start-menu contractに影響なし
- ホストハーネスで6キーフレームがPNG出力される

### 未検証（実機でしか確認できない）

**以下はすべて動く保証がない。**

- 実機パネルへの表示（blit経路、色順、stride）
- 入力（joypad node検出、ボタン割り当て）
- **DRM master受け渡し**（GGFE→RetroArch→GGFE復帰）
- 60fps維持
- 起動から復帰までの一連の流れ
- **GGFEの相対パスと `plumos-text-ui` の相対パス規約が一致するか**（→ 5章）

## 3. デプロイ

**バイナリ単体でデプロイしてはならない。** AGENTS.mdの規定どおり、
`checksums.sha256` と `manifest.json` を同一デプロイ単位で整合させる。

GGFEの追加物は以下すべてがcheckum対象に入っている。

```
bin/plumos-ggfe
bin/plumos-ggfe-launch
config/frontend/ggfe.json
factory-defaults/frontend/ggfe.json
themes/default/ggfe/logo-strip.png
themes/default/ggfe/header-logo.png
config/frontend/apps.json                  （ggfe項目を追加）
config/frontend/start-menu-coverage.json   （bubble_only_apps_entries に ggfe）
```

したがって **frontendコンポーネントごと入れ替えるのが確実**である。

```
./scripts/build-bubble-frontend.sh
# 出力: output/frontend/bubble/plumos/
```

再起動前に実機上でSHA-256とapp-layer checksum検証を実行し、bootstrapが
`critical checksum failed` で拒否しないことを確認すること。

## 4. 動作試験の手順

### 4.1 まずFEを経由せず単体で起動する

いきなりApps経由で試すと、失敗時に「FEの問題か、GGFEの問題か、DRMの問題か」が
切り分けられない。**validation holdを使って単体起動する。**

```sh
mkdir -p /run/plumos/validation
touch /run/plumos/validation/frontend-hold
# ここで既存FEを再起動させると、FEは起動せず待機に入る
```

この状態でDRMと入力が空くので、GGFEを直接起動できる。

```sh
PLUMOS_ROOT=/storage/plumos \
PLUMOS_SDCARD_ROOT=/storage \
sh /storage/plumos/bin/plumos-ggfe-launch
```

**FEをSSHから繰り返しkillしてはならない。** 過去に early init の4回制限を消費して
FEが上がらなくなった事例が
`docs/validation/2026-09-03-bubble-renderer-pfs-governor.md` に記録されている。
holdマーカーを消してから再起動するのが正しい戻し方である。

### 4.2 確認項目

| # | 項目 | 期待 |
|---|---|---|
| 1 | 起動 | カートリッジが表示される。`logs/ggfe.log` に `ggfe_start=ok roms=N` |
| 2 | 走査 | Nが `/storage/Roms/{GG,GameGear,MD,gamegear}` のROM数と一致 |
| 3 | サムネ | 取得済みのものが表示される。無い場合はROM名の板 |
| 4 | 十字操作 | 左右（上下）でカルーセルが動き、タイトルが切り替わる |
| 5 | フレーム | スクロールとアニメーションが滑らか |
| 6 | A | ケースが開く→カートが飛び出す→本体が競り上がる→挿入→白フラッシュ |
| 7 | 起動 | RetroArchが立ち上がりゲームが動く |
| 8 | 復帰 | ゲーム終了でGGFEへ戻り、**画面が正しく再取得される** |
| 9 | B/START | 既存FEへ戻る |
| 10 | Apps経由 | START→Apps→Game Gear で同じ結果 |

8が最大の関門である。`ggfe_renderer=reacquire-failed` が出ていないか必ず確認する。

### 4.3 記録

結果は `docs/validation/YYYY-MM-DD-bubble-ggfe-*.md` へ既存の形式で残す。
最低限、走査数、選択操作、起動、復帰、DRM再取得、fps体感、失敗した項目を記載する。

## 5. 最も可能性が高い失敗要因

### 相対パス規約の不一致

GGFEは自前でROMを走査し、plumOS scan cacheと同じくaliasを含む
`<alias>/<ROM>`を起動用相対パス `rel` として持つ。サムネイル探索だけは
`Roms/<alias>/` からの相対パスを使い、既存のImages配置を維持する。

```
plumos-text-ui launch gamegear <rel> --profile <id> --execute
```

`plumos-text-ui` 側は `load_selected_rom()` で自前の走査結果から `rel` を引く。
**両者の相対パス規約が一致している前提だが、実機で未確認である。**

切り分けは `--execute` を外した dry run で単独に行える。

```sh
/storage/plumos/bin/plumos-text-ui launch gamegear 'gamegear/Sonic.gg'
```

`command:` と `can_execute: yes` が出れば規約は一致している。
`error:` が出るなら不一致で、GGFE側の `rel` 生成（`ggfe_walk()`）を合わせる必要がある。
**GGFEを実機で起動する前に、この1コマンドだけ先に試すのが最も効率が良い。**

## 6. 仕様であって不具合ではない挙動

- **動かせるコアが無いカートリッジではAを押しても何も起きない。**
  挿入アニメーションを再生してから失敗するのを避けている。
  `logs/ggfe.log` に `ggfe_launch=unavailable rom=... reason=...` が出る。
- **jpg / jpeg / webp のサムネは解決されるが表示されない。**
  解決規則は既存FEと同一に保つ一方、本ビルドはlibpngしかリンクしていないため
  ROM名の板になる。libjpeg導入はtools imageと `frontend/lib` の両方に影響するため分離した。
- **画面上にボタン説明は出さない。** 操作は `docs/ggfe.md` で告知する方針。
- **CPU policyをGGFEは指定しない。** `plumos-text-ui` 側のチェーンが
  `systems.json` と `core-overrides.json` から解決する。GGFEが指定すると
  既存FEでユーザーが設定した値を上書きしてしまう。

## 7. 設定と状態ファイル

`config/frontend/ggfe.json` の詳細は `docs/ggfe.md` を参照。

**GGFEは `state/frontend/core-overrides.json` を読むが、絶対に書かない。**
既存FEで選んだコアは尊重されるが、ファイルの所有は分離されている。
GGFEが書くのは `state/frontend/ggfe-overrides.json` のみ（現状はUI未実装のため
手編集のみ）。この分離は意図的なので、書き込み側を増やさないこと。

## 8. テスト実行時の注意

**macOSのbash 3.2は `set -e` で `[[ ]]` の失敗を無視する。**
`tests/` 配下の素の `[[ ]]` アサーションはmacOS上で無言スキップされ、
スクリプトは `result-ok` を印字する。実際に検証したいならcontainer（bash 5.2）で
実行すること。

```sh
docker run --rm --platform linux/arm64 -v "$PWD:/work" -w /work \
  plumos-bubble-tools:dev bash -c './tests/test-bubble-start-menu-contract.sh'
```

`tests/test-bubble-ggfe-launch-resolution.sh` は `if ... then fail; fi` 形式で
書いてあるため両方で正しく落ちる。既存testの形式変換はTODO.mdに記載済み。

## 9. 未実装

- コア選択UI（解決結果と各profileの未対応理由は取得済み。オーバーレイで選ばせて
  `ggfe-overrides.json` へ書き戻すだけ）
- jpg / webp のデコード
- 実機acceptance全般

実機で問題や要望が洗い出されるまで、コアの切り出し（別リポジトリ化）は保留している。
