# Wi-Fiとファイル転送

## Wi-Fi

`START` → `ネットワーク設定`からWi-FiをONにし、`Wi-Fi に接続`でSSIDとpasswordを
設定します。接続後は`情報`でIP addressを確認します。Wi-FiをOFFにした直後はservice停止に
数秒かかることがあります。

## 接続方法

初期credentialは次のとおりです。passwordは利用開始後に変更してください。

| 方法 | 接続先／port | user | password | 用途 |
| --- | --- | --- | --- | --- |
| SSH | BubbleのIP / 22 | `root` | `plumos` | shell |
| SFTP | BubbleのIP / 22 | `root` | `plumos` | 安全なfile transfer |
| FTP | BubbleのIP / 21 | anonymous | 不要 | 簡易file transfer |
| Samba | `\\<IP>\SDCARD` | `plumos` | `plumos` | Windows/macOSの共有 |

FTP、SFTP、Sambaはいずれも利用者領域を参照します。ROMを追加する場合は
`Roms/<system>/`、BIOSは`BIOS/`へ置きます。転送完了後は一覧を更新してください。

## 注意

- 公衆LANへ接続する前に初期passwordを変更してください。
- ADB項目はありません。USBは充電専用です。
- 接続できない場合は同じLANにいること、IP address、client側firewallを確認します。
- 途中までの大容量fileが残った場合は、再転送前にsizeまたはhashを確認します。
