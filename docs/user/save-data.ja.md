# BIOS、save、state、スクリーンショット

## BIOS

利用者が権利を持つBIOSを`BIOS/`へ置きます。SD2が装着されている場合はSD2ルートの
`BIOS/`が利用され、未装着時はSD1の`BIOS/`が利用されます。

Sega CD、Saturn、PlayStation、PC Engine CD、Neo Geo CD、PC-FXなどのdisc system、
computer系、arcadeの一部は、正しいBIOSや正しいROM setがないと起動しません。
拡張子が一覧に含まれることは、BIOS不要や全ゲーム互換を意味しません。

## 保存先

| 種類 | 実機上の場所 |
| --- | --- |
| RetroArch save | `/storage/plumos/saves/` |
| RetroArch save state | `/storage/plumos/states/` |
| スクリーンショット | `/storage/Images/`（FAT32の`Images/`） |
| 設定 | `/storage/plumos/config/` |
| ログ | `/storage/plumos/logs/` |

StandaloneやPortsは各runtime固有の場所を使う場合があります。save／state／設定／logは
PCへSYSカードを直接挿した際のFAT32領域ではなく、device管理partitionにあります。
SFTPまたはSambaでbackupしてください。system updateはこれらを保持する設計です。

## Game Gear B3 shader

Game Gearの既定shaderは`/storage/plumos/config/shaders/gamegear-lcd.glslp`です。B3は
SEGA型STN panelの色、横長pixel、垂直RGB構造、水平CCFL、非対称responseを再現します。
利用者が値を変更する場合は先にファイルをbackupしてください。
