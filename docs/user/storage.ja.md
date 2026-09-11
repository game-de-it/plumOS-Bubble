# SD1 / SD2の使い分け

## SD1（本体上部のSYSスロット）

起動用カードです。内部にはdevice管理のSystem領域と、PCから見えるFAT32の`PLUMOS`
領域があります。PCから直接扱う主なfolderは次のとおりです。

- `Roms/`: ROMとゲーム起動ファイル
- `BIOS/`: 利用者が用意するBIOS
- `Images/`: スクリーンショットと画像
- `updates/`: system update package

実機のdevice管理領域には`/storage/plumos/saves`、`states`、`config`、`logs`もあります。
これらはSFTPやSambaでbackupできますが、System管理fileやmanifestを不用意に変更しないで
ください。PCへSYSカードを直接挿したときの`PLUMOS`領域とは別partitionです。

## SD2（本体下部のSD2スロット）

任意のFAT32カードです。ルートの`Roms`（`roms` / `ROMS`も認識）と`BIOS`
（`bios` / `Bios`も認識）を利用します。SD2が装着されていれば、そのROM／BIOS
領域が優先されます。設定、save、state、画像、ログは引き続きSD1に保存されます。

SD2を使わなくてもSD1だけでゲーム一覧、スクレイピング、サムネイル表示、ゲーム起動
を利用できます。

## 安全な扱い

- SD2の挿抜は必ず電源OFFで行います。hot plugは対応外です。
- SYSカードはshutdownが完了して画面とLEDが消えるまで抜きません。
- 大文字小文字違いのROMフォルダを重複して作らないでください。
- 破損が疑われるFAT32のSD2は`START` → `Apps` → `Repair SD2`を使えます。
  表示内容を確認し、5秒以内にもう一度`A`を押すと検査・修復を始めます。
  実行中は電源を切ったりカードを抜いたりしないでください。SYSカードは対象外です。
