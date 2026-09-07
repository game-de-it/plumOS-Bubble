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

### ホスト側で検証済み

- RetroArchビルドが通り、3ファイルが `factory-defaults/shaders` へ入りchecksumに載る
- `plumos-retroarch-launch` が `config/shaders` へ**上書きせず**seedする
- RetroArch関連4テスト通過
- **見た目**は `scripts/preview-gamegear-lcd.py` によるnumpy再実装で確認済み。
  既定値はこれでスイープして決めた

### 未検証

**GLSLは一度もコンパイルされていない。**
ツールイメージにglslangValidatorが無く、apt取得もできなかった。
したがって以下はすべて実機で初めて分かる。

- シェーダーがコンパイルを通るか
- uniform名が正しいか（→ 5章）
- 実機パネルでの見え方
- フレームレートへの影響

## 3. デプロイ

**retroarchコンポーネントごと入れ替える。** checksums/manifestの整合が必要。

```
./scripts/build-bubble-retroarch.sh
# 出力: output/retroarch/bubble/plumos/
```

`video_shader_enable` は出荷時 `false` なので、**入れただけでは何も変わらない**。
明示的にプリセットを読むまで従来どおり動作する。安全側に倒してある。

## 4. 動作確認手順

### 4.1 まず切り分け用のパス2だけを読む

いきなり本体を読むと、失敗したときにパス1とパス2のどちらが原因か分からない。

```
RetroArch menu > Shaders > Load Preset > gamegear-lcd-panel-only.glslp > Apply
```

**ここで色味とセル構造が出れば、パス2は正常。** 出なければパス2の問題。

### 4.2 本体を読む

```
RetroArch menu > Shaders > Load Preset > gamegear-lcd.glslp > Apply
```

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
| 青被りが強すぎる／足りない | `Blue cast` |
| 横線が目立ちすぎる／見えない | `Row gap` |
| 色縞がうるさい | `Subpixel strength` を下げる |
| 眠すぎる／コントラストが強すぎる | `Black level` と `White level` |
| 残像が長すぎる／足りない | `LCD fall speed`（下げると尾が伸びる） |

調整結果が良ければ、その値を `gamegear-lcd-panel.glsl` の `#pragma parameter`
既定値へ反映してコミットすること。実機で決めた値のほうが正しい。

## 7. 仕様であって不具合ではない挙動

- **高速で動くものが最大輝度に届かない。** STNパネルの実際の挙動である。
- **サブピクセルは3x前提で位相を合わせてある。** 整数3x以外に拡大された場合は
  位相が合わず色縞になる。その場合は `Subpixel strength` を下げる。
- **静止画では残像が出ない。** 履歴と現在値が一致するため、パス1は素通しになる。

## 8. 有効化を既定にする場合

現状は手動ロードのみ。既定で当てたい場合は `auto_shaders_enable` が既に `true` なので、
RetroArchのシェーダーメニューから「コア別プリセット」または「コンテンツ別プリセット」
として保存すれば次回から自動適用される。

**`video_shader_enable = true` を出荷設定に入れるのは避けたほうがよい。**
Game Gear以外のシステムにも当たってしまう。
