# エミュレータのメニューとホットキー

## ボタン位置

- **Function 1（F1、本体前面）**: 基本のエミュレータメニューボタン
- **Function 2（F2、本体上部）**: RetroArchのスクリーンショットなど

「上部のFunction」と覚えるとSYSスロット付近のFunction 2を押しやすいため、
メニューを開くときは**前面のFunction 1**であることに注意してください。

## RetroArch（RA）

| 操作 | 動作 |
| --- | --- |
| Function 1（本体前面） | RetroArchメニュー表示／ゲームへ戻る |
| Function 2（本体上部） | スクリーンショット保存 |
| `SELECT` + `START` | ゲームを終了してフロントエンドへ戻る |
| `SELECT` + `L` | stateをload |
| `SELECT` + `R` | stateをsave |
| `SELECT` + 十字左／右 | state slotを前／次へ変更 |
| `SELECT` + `Y` | FPS表示切替 |
| `SELECT` + `R2` | fast-forward切替 |
| `SELECT` + `L2` | slow-motion切替 |

スクリーンショットはSD1の`Images/`へ保存され、フロントエンドの画像として利用
できます。ゲームやcoreによってsave stateを安全に利用できない場合があります。

## PicoArch（PICO）

Function 1（本体前面）でPicoArchメニューを開きます。終了、save、loadなどは
メニューから実行してください。RetroArch用のすべての組み合わせがPicoArchにも
適用されるわけではありません。

## Standaloneエミュレータ（SA）

| エミュレータ | メニュー |
| --- | --- |
| PPSSPP（PSP） | Function 1（本体前面） |
| PCSX-ReARMed standalone（PlayStation） | Function 1（本体前面） |
| YabaSanshiro（Saturn） | Function 1（本体前面） |
| OpenBOR | Function 1（本体前面） |
| DraStic（Nintendo DS） | Function 1（本体前面）で通常メニュー |

DraSticではFunction 2（本体上部）+`START`でも簡易メニューを表示できます。
通常の設定・save・終了にはFunction 1（本体前面）の通常メニューを推奨します。

## PortMaster / Ports

Portsには共通の`SELECT`+`START`終了契約はありません。各ゲーム自身の終了メニューを
利用してください。ゲームごとに操作体系が異なります。

## Pyxel

Pyxel applicationにはRetroArchのような共通quick menuはありません。終了方法と操作は
各applicationの実装に従います。応答しない場合は本体の電源メニューから終了／再起動を
行ってください。

## Game Gear専用フロントエンド（GGFE）

`START` → `Apps` → `Game Gear`から起動します。

| 操作 | 動作 |
| --- | --- |
| 十字左／右 | 前／次へ移動。長押しrepeat、端で折り返し |
| 十字上／下 | 5件前／5件先へ移動 |
| `A` | ゲーム起動 |
| `X` | cartridge case表示切替 |
| `SELECT` | GGFEメニュー表示 |
| `B` / `START` | 一覧画面では何もしない |

GGFEメニュー内は上下で行移動、左右で値変更、`A`で選択、`B`または`SELECT`で
閉じます。ゲーム起動後は選択したRA/PICOの操作体系へ切り替わります。

## 電源操作

どの経路でも、再起動／shutdownは電源メニューまたはフロントエンドへ戻ってから
行うのが基本です。画面が真っ暗でも電源メニューを呼び出せるよう、停止処理が先に
走ります。通常の終了が可能なら強制電源断は避けてください。
