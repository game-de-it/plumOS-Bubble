# Game Gear LCD shader baselines

この文書は、実機で見え方を確認したシェーダーセットへ短い名前を与え、後続の比較で
「どの状態との比較か」を曖昧にしないための台帳である。baselineは完成版を意味せず、
未解決項目を追う際の既知の復帰点を意味する。

## SEGA-HCCFL-B1

正式呼称: **SEGA Horizontal CCFL Baseline 1**

Git tag: `shader-sega-hccfl-b1`

### この名前が示す状態

- SEGA版パネルの色調
- 640x480の4:3非スクエアピクセル表示
- RGB素子、黒マトリクス、横線構造
- 色主体の拡散と上方向1ソース行の非対称侵食
- 中央の明侵食100%、中央の暗侵食20%
- 横向きCCFL管を線分光源として扱うカプセル状の連続光量分布
- 外周の暗侵食75%
- Sonic 2の`THE HEDGEHOG`とcopyright/footerの見え方を実機で合格とした状態

### ここでは未解決のもの

パネルに見える黒い縦線の発生理由と再現方法は、このbaselineには含めない。
今後の縦線候補は必ず`SEGA-HCCFL-B1`と同一場面で比較し、失敗時はこのタグへ戻せる
状態を保つ。

### ファイル識別子

```text
4b25937456e7ebff6f6e586e097b138a4d4565c7c2ec30991e82a2a16347a3ac  configs/retroarch/shaders/gamegear-lcd.glslp
3cf9ec8273ed49f106c94f0e104842449658b2faac9bf6c04fbf662bbeb5a6a6  configs/retroarch/shaders/gamegear-lcd-response.glsl
69c7970fd808fbc200b405e6bedffb432b144bff2cdf74d112e83a4d691f9926  configs/retroarch/shaders/gamegear-lcd-panel.glsl
66df44db5c4dc95df72af0f77ea74b747c503c3c66d09d39391467c9a21c3a44  configs/retroarch/shaders/gamegear-lcd-optics.glsl
31c243d52b5b085e7da5ed85e5b2f1f336879eb3a147c21382e76f636423c3f7  configs/retroarch/shaders/gamegear-lcd-panel-only.glslp
3cafc235d65e99718a61c78fb9b087978b90525038a934979d094e8057230ad7  scripts/preview-gamegear-lcd.py
4d5de4452eb0aad6a8550a38b9717219ab214b4cecca8f4062f19a9ae30a9d2e  package/frontend-bubble/plumos/bin/plumos-retroarch-launch
```

`SEGA-HCCFL-B1`を実機へ適用した時点のpanel shaderも
`69c7970fd808fbc200b405e6bedffb432b144bff2cdf74d112e83a4d691f9926`
へreadback一致済み。デプロイとrollback情報は
`docs/validation/2026-09-08-bubble-gamegear-horizontal-ccfl.md`を参照する。

### 比較時の呼び方

- 現在の基準: `SEGA-HCCFL-B1`
- 次の縦線候補: `B1 + <候補名>`
- 比較結果: `B1比`で、縦線、THE、footer、色、明暗、fpsを個別に記録する

## SEGA-HCCFL-B2

正式呼称: **SEGA Horizontal CCFL Baseline 2**

Git tag: `shader-sega-hccfl-b2`

### この名前が示す状態

- B1の4:3非スクエアピクセル、上方向侵食、時間応答、横向きCCFLを維持
- 実機パネル観察に合わせ、横方向の黒線を廃止
- 1ソースpixelを等幅の`R/G/B/K` 4帯として表示
- R/G帯85%、B帯25%、K帯0%により、BとKが連続する太い暗線を形成
- 青背景の参照画像へ合わせ、黒レベル0.12、青領域彩度1.20、青→緑漏れ0.15
- 中央の明侵食100%、中央の暗侵食20%、外周の暗侵食90%
- 縦黒線と青色を維持したまま、footerの白を外周暗侵食で弱める

### ファイル識別子

```text
4b25937456e7ebff6f6e586e097b138a4d4565c7c2ec30991e82a2a16347a3ac  configs/retroarch/shaders/gamegear-lcd.glslp
3cf9ec8273ed49f106c94f0e104842449658b2faac9bf6c04fbf662bbeb5a6a6  configs/retroarch/shaders/gamegear-lcd-response.glsl
0744f57ff36af4568490073bde1dbbd4f5cff45d728dcc1ebf77705abe92267f  configs/retroarch/shaders/gamegear-lcd-panel.glsl
66df44db5c4dc95df72af0f77ea74b747c503c3c66d09d39391467c9a21c3a44  configs/retroarch/shaders/gamegear-lcd-optics.glsl
31c243d52b5b085e7da5ed85e5b2f1f336879eb3a147c21382e76f636423c3f7  configs/retroarch/shaders/gamegear-lcd-panel-only.glslp
7aa4fa5b821273d877c69c305e00602aa4254c13b4d016aa88b1be996c812180  scripts/preview-gamegear-lcd.py
4d5de4452eb0aad6a8550a38b9717219ab214b4cecca8f4062f19a9ae30a9d2e  package/frontend-bubble/plumos/bin/plumos-retroarch-launch
```

実機のactive panel shaderは
`0744f57ff36af4568490073bde1dbbd4f5cff45d728dcc1ebf77705abe92267f`
へreadback一致済み。直前のB2各段階は実機上の
`/storage/plumos/state/shader-backups/20260908-*`に保存されている。

### 比較時の呼び方

- 現在の基準: `SEGA-HCCFL-B2`
- B2から一要素を外す比較: `B2 - <補正名>`
- B2へ一要素を加える比較: `B2 + <候補名>`
