# 問題が起きたとき

## ゲームが一覧にない

1. [対応システム一覧](supported-systems.ja.md)でフォルダ名と拡張子を確認します。
2. `SHOW EMPTY SYSTEM`をOFFにしている場合、そのsystemは認識ROMがなければ隠れます。
3. 同名フォルダの大文字小文字重複を避け、一覧更新または再起動を行います。
4. SD2使用時は電源OFFで正しく挿入し直します。

## 起動しない／黒い画面

- disc systemはBIOS、`.cue`のtrack参照、`.m3u`のpathを確認します。
- arcadeはcoreとROM setのversionを合わせます。
- ゲーム選択中の`SELECT`から別coreを試します。
- Function 1（本体前面）でエミュレータメニューが出るか確認します。
- 電源メニューで終了／再起動します。FEとエミュレータをSSHから同時起動しないでください。

複数の描画processが同時に画面を所有すると点滅やimage retentionの原因になります。
診断のため直接エミュレータを起動する場合も、通常のFE経路を使用してください。

## 音が小さい／飛ぶ

FEとエミュレータ双方のvolume、イヤホン検出を確認します。N64など重いsystemは
Performance profileが必要です。ゲームやsceneによってはRK3566の性能限界で音飛びが
残る場合があります。

## SD2の問題

電源OFFで挿し直します。FAT32で認識するが破損が疑われる場合は`START` → `Apps` →
`Repair SD2`を使用します。SYSカードへは使用できません。PCが修復を求める場合や
mechanical failureが疑われる場合は、先にimageまたは重要fileをbackupしてください。

## Wi-Fi／スクレイピング

再起動後にWi-FiをONにし、IPと時刻を確認します。SSIDが見えなければscanをやり直し、
routerとの距離とbandを確認します。診断ログはSD1の`plumos/logs/`にあります。

## 強制電源断

通常のpower menuを先に試します。screenが消えてもLEDが残る場合は少し待ちます。
強制電源断はfilesystem破損の可能性があるため、通常経路が使えない最後の手段です。
