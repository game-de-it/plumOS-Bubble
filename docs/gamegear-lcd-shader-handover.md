# Game Gear LCDシェーダー 導入・動作確認 引き継ぎ

この文書はGame Gear LCDシェーダーをBubble実機へ導入し、受け入れ確認を行うための
引き継ぎである。シェーダーが何を再現しているか、パラメータの意味は
`docs/gamegear-lcd-shader.md` を参照する。

## 1. 位置づけ

RetroArchでGame Gearを動かしたときに、汎用のLCDフィルタではなく**実機のパネル**の
見え方を再現する。実機写真を基準に調整してある。

GGFEとは独立している。GGFEを使わずRetroArchを直接起動しても効く。

### ファイル

| パス | 内容 |
|---|---|
| `configs/retroarch/shaders/gamegear-lcd.glslp` | 本体（2パス） |
| `configs/retroarch/shaders/gamegear-lcd-response.glsl` | パス1: パネル応答（残像） |
| `configs/retroarch/shaders/gamegear-lcd-panel.glsl` | パス2: セル構造・色域・バックライト |
| `configs/retroarch/shaders/gamegear-lcd-panel-only.glslp` | 切り分け用（パス2のみ） |
| `scripts/preview-gamegear-lcd.py` | ホスト検証（numpy再実装） |

### なぜGLSLなのか

`scripts/build-bubble-retroarch.sh` が `--enable-opengles --disable-opengl_core` で
構成しているため、**この機体にはglcoreもVulkanも無く、slangは読み込めない**。
GLSL以外の形式を書いても動かない。

## 2. 現状（検証済みと未検証を厳密に分ける）

### 実機で確認済み（2026-09-07）

- panel-only版・FULL版とも読み込めた。**GLSLはコンパイルを通る**
- 過去フレームのuniform名も、明るさの差が報告されていないことから正しいと判断
- 実機フィードバックを受けて調整済み: 明るさ、コントラスト（より白っぽく）、
  RGB素子のサイズ

### ホスト側で検証済み

- RetroArchビルドが通り、4ファイルが `factory-defaults/shaders` へ入りchecksumに載る
- `plumos-retroarch-launch` が `config/shaders` へ**上書きせず**seedする
- `system=gamegear`だけがKMS/EGL/GLESへ切り替わり、2パス版を
  `--set-shader`で読むlauncher contractが通る
- NESなどの非Game Gear経路はplain DRMのままで、同じGenesis Plus GXを使う
  Master System/Mega Driveにも波及しない
- 切り分け用の`panel-only`と緊急回避用の`off`、不正値拒否がhost testを通る
- **見た目**は `scripts/preview-gamegear-lcd.py` によるnumpy再実装で確認済み。
  既定値はこれでスイープして決めた

### 未検証

ツールイメージにglslangValidatorが無いためコンパイル検証はホストでは行えない。
初回の実機確認でロードは通ったが、以下は未確認のまま。

- 調整後の見え方（前回の実機確認は調整前の値）
- フレームレートへの影響
- 残像の効き具合（動きのあるゲームでの確認が必要）

## 3. デプロイ

**retroarchとfrontendの2コンポーネントを同じapp-layer更新単位で入れ替える。**
シェーダー本体はretroarch、Game Gearだけへ限定する起動契約はfrontendが所有する。
checksums/manifestの整合が必要。

```
./scripts/build-bubble-retroarch.sh
./scripts/build-bubble-frontend.sh
./scripts/build-bubble-app-layer.sh --assemble-only
```

永続cfgの`video_shader_enable`は`false`のままにする。Game GearのRetroArch起動時だけ
launch append cfgで有効にし、`gamegear-lcd.glslp`を指定する。これにより他systemは
従来どおりで、ユーザーのRetroArch設定も書き換えない。

GGFEでPicoArch profileを選んだ場合はRetroArchシェーダーを利用できない。
`retroarch:genesis_plus_gx`、`retroarch:picodrive`、`retroarch:gearsystem`のいずれかを
選んだ場合に適用される。

## 4. 動作確認手順

### 4.1 まず切り分け用のパス2だけを読む

いきなり本体を読むと、失敗したときにパス1とパス2のどちらが原因か分からない。

validation holdでFEの停止を確認してから、通常launcherへ
`PLUMOS_GAMEGEAR_LCD_PRESET=panel-only`を渡してGame Gearを起動する。
RetroArchメニューから手動ロードする場合は
`Shaders > Load Preset > gamegear-lcd-panel-only.glslp > Apply`でもよい。

**ここで色味とセル構造が出れば、パス2は正常。** 出なければパス2の問題。

### 4.2 本体を読む

`PLUMOS_GAMEGEAR_LCD_PRESET`を付けない通常FE経路で起動する。既定はfullであり、
`gamegear-lcd.glslp`が自動適用される。切り分け時だけ明示的に`full`を渡してもよい。

シェーダーが起動不能または著しい性能低下を起こす場合に限り、切り分け用として
`PLUMOS_GAMEGEAR_LCD_PRESET=off`を使える。これは永続設定を変更しない。

### 4.3 確認項目

| # | 項目 | 期待 |
|---|---|---|
| 1 | ロード | エラーにならない |
| 2 | 色味 | 全体が青緑に寄り、明るいグレーが淡い青になる |
| 3 | 構造 | 細い横線が見え、その間に色のテクスチャがある |
| 4 | 残像 | 動くものが尾を引く。静止画では尾は出ない |
| 5 | 明るさ | パス2のみ と 本体 で明るさがほぼ同じ |
| 6 | fps | シェーダー有効時も従来どおり |
| 7 | 復帰 | 終了してFEに戻れる |

**5が重要**である。理由は5章。

### 4.4 記録

`docs/validation/YYYY-MM-DD-bubble-gamegear-lcd-shader.md` へ既存形式で残す。
実機写真があると調整に直結するので、可能なら添付する。

## 5. 最も可能性が高い失敗要因

### 過去フレームのuniform名（サイレント失敗しうる）

パス1は過去の入力フレームを以下の名前で受け取る前提で書いてある。

```
PrevTexture, Prev1Texture, Prev2Texture, Prev3Texture
```

RetroArchのGLSL仕様ではこれで正しいはずだが、**確認できていない**。

厄介なのは、**名前が違ってもコンパイルは通る**ことである。バインドされない
samplerは黒を返すため、エラーにはならず「全体が暗くなる」という形で出る。

切り分けは4章の手順で完結する。

- パス2のみ → 正常な明るさ
- 本体 → 明らかに暗い、または動きに対して妙に鈍い

この症状なら過去フレームのバインドを疑う。応急処置としては
`gamegear-lcd-panel-only.glslp` をそのまま使えばよい（残像以外は再現される）。

### 精度

セル位相は「ソースのピクセル番号」から作るので、値が160に達する。
mediumpだと分解能が約1/8しかなく、`fract()` が量子化してストライプが縞になる。
`GL_FRAGMENT_PRECISION_HIGH` があればhighpを要求するようにしてあるが、
Mali側がこれを持たない場合は縞が出る可能性がある。

症状が出た場合は `Subpixel strength` を下げれば緩和する。

## 6. 見え方が違うときのパラメータ

RetroArchのシェーダーパラメータメニューから調整できる。実機を見ながら振るのが早い。

| 症状 | 触るもの |
|---|---|
| 全体が暗い／明るすぎる | `Brightness`（倍率ではなく飽和定数。上げるほど明るく眠くなる） |
| 眠すぎる／コントラストが強すぎる | `Black level`（下げると締まる） |
| 青被りが強すぎる／足りない | `Blue cast` |
| 横線が目立ちすぎる／見えない | `Row gap` |
| RGB素子が小さい／大きい | `Subpixel size (cells)`。1が実寸、2以上は強調 |
| 色縞がうるさい | `Subpixel strength` を下げる |
| 残像が長すぎる／足りない | `LCD fall speed`（下げると尾が伸びる） |

調整結果が良ければ、その値を `gamegear-lcd-panel.glsl` の `#pragma parameter`
既定値へ反映してコミットすること。実機で決めた値のほうが正しい。

## 7. 仕様であって不具合ではない挙動

- **高速で動くものが最大輝度に届かない。** STNパネルの実際の挙動である。
- **サブピクセルは3x前提で位相を合わせてある。** 整数3x以外に拡大された場合は
  位相が合わず色縞になる。その場合は `Subpixel strength` を下げる。
- **静止画では残像が出ない。** 履歴と現在値が一致するため、パス1は素通しになる。

## 8. 自動適用の境界

既定でGame Gearへ適用するが、`video_shader_enable = true`を出荷cfgへは入れない。
system idを見られる`plumos-retroarch-launch`が起動単位で適用する。

コア別プリセットとして保存してはならない。Genesis Plus GXやPicoDriveはGame Gear以外も
実行するため、Master System、Mega Drive、Sega CDへ誤適用される。
