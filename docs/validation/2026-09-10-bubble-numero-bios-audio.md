# Bubble Numero BIOS and audio classification

Date: 2026-09-10

## Device result

FEのTI-83から`Tetris.8xp`を起動したところ、Numeroのエラー画面が表示された。RetroArch logでは
content、XRGB8888、640x480 geometryまで初期化され、core timingは`Sample rate: 0.00 Hz`だった。
実機のuser-owned BIOS領域にはNumeroが受理するROMが存在しなかった。

## Pinned-source result

Bubbleが固定するNumero source `19354c9bfe06a3e4fd936961ee8414b040a3d1c6`は、system directoryから
次の順で最初に存在するROMを使用する。

1. `ti83se.rom`（推奨）
2. `ti83plus.rom`
3. `ti83.rom`

どれもなければ、今回確認した案内画面をcore自身が描画する。一方、同sourceはlibretro timingの
sample rateを0に固定し、audio callbackを保存するだけでフレーム生成時に呼び出さない。したがって
NumeroはBubbleの音声確認対象にはできず、BIOSを追加しても音声は出ない。

## Metadata correction

upstream core-infoには上記BIOSが収録されていなかった。package時に3ファイルを
`firmware_policy=required-any`として補正し、runtime coverageとcatalog verifierで固定する。
BIOS本体はproprietaryなuser-owned dataであり、repositoryやapp-layerには収録しない。
