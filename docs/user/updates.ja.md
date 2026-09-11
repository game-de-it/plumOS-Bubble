# 更新

plumOS Bubbleの更新packageは署名と機種、versionを検証します。同じversionや古いversion
へのdowngradeは拒否されます。

1. Bubble用の正しいupdate packageと公開されたchecksumを取得します。
2. checksumを確認します。
3. SYSカードをPCへ接続した場合は`PLUMOS`領域の`updates/`へコピーします。network共有
   からは`user/updates/`、実機pathでは`/storage/user/updates`です。
4. `START`メニューの更新導線から実行し、表示されたversionを確認します。
5. 完了するまで電源を切ったりSYSカードを抜いたりしません。
6. 再起動後にversion、ゲーム一覧、Wi-Fi、saveを確認します。

updateはROM、BIOS、save、state、設定、theme、download済みPort、network情報を保持する
設計です。ただし重要な利用者データは事前にbackupしてください。raw SD imageの書き直し
はupdateではなく、新規installとして扱います。
