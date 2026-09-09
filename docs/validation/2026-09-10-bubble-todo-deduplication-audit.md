# Bubble TODO evidence deduplication audit (2026-09-10)

## Purpose

未完了gateを新しい実機試験の一覧として扱うのではなく、過去のbuild、block readback、
boot log、runtime probe、利用者の物理操作報告へ逆引きした。同じ操作をruntimeやsubtaskごとに
再要求せず、gate本文のacceptanceを既存証跡が満たすものを完了へ統合した。

## Gates closed from existing evidence

| Gate | Consolidated evidence |
| --- | --- |
| `BUB-P1-02` | raw 16 MiB Rockchip prefix、active boot matching set、kernel/DTB/overlay、System、module/firmwareをhash固定し、再現imageを独立検証済み。未使用sectorを含むbit cloneではなく「復元に必要な全領域」条件を採用した。 |
| `BUB-P1-08` | captured substrateを含むprivate full imageを新SDへfull writeし、block readback、filesystem検査、cold bootを実施済み。 |
| `BUB-P1-10` | 電源断中のOS SD交換、known imageの起動、persistent stage log、Wi-Fi/SSH、normal poweroff、host readbackを実証済み。UARTは必須経路にせずrecovery SSHとSD readbackを使う。 |
| `BUB-P2-03` | cold bootはexternal init 1.16 s、System 3.38 s、FE開始5.43 s、ready約11 s。後続warm rebootはbackend requestまで2 s、次boot FE開始3.84--3.89 s。 |
| `BUB-P4-D02` | CPU dumb-buffer double buffering、blocking commit＋completion event、menu/game barrier完了、RGUI複数往復、FE再取得を実機確認済み。追加read-only計測は100 ms間隔60/60成功、FB 158/159が29/31回、DRM ownerは前後ともFE PID 338。 |
| `BUB-P4-I03` | power、volume GPIO、全controller、G-sensor capabilityを採取済み。power/volumeは物理操作済み。G-sensorは現行runtime非使用、rumbleは必須機能とせず未確認FF actuatorへ出力しない方針を確定した。 |
| `BUB-P4-A02` | QuickNES speakerを301秒、60/60 `RUNNING`、pointer stall 0、XRUN 0、S32_LE/48 kHz/stereoで実測し、利用者も音声を確認済み。N64の場面依存XRUNは既知core制約として別matrixへ記録した。 |
| `BUB-P6-09` | 全物理controlのordered captureとevdev/js map、全runtime設定の機械照合、RetroArch/PicoArch/DraStic/PPSSPP/PortMaster/SDL系の代表物理操作、menu/exit、volume/powerを統合して合格とした。全buttonを全runtimeで組合せ再試験しない。 |
| `BUB-NEXT-01` | 旧private 3-partition開発probeのstage、Wi-Fi、SSH、shutdown、filesystem条件は後続のfull-image boot/readbackで包含されたため、独立した重複gateを完了とした。 |

主な既存記録:

- `docs/validation/2026-09-02-bubble-external-initramfs-probe-host.md`
- `docs/validation/2026-09-01-bubble-recovery-network-seed-host.md`
- `docs/validation/2026-09-03-bubble-fast-boot-physical.md`
- `docs/validation/2026-09-10-bubble-state-reboot-physical.md`
- `docs/validation/2026-09-03-bubble-nes-audio-pyxel.md`
- `docs/validation/2026-09-10-bubble-nes-audio-five-minute.md`
- `docs/validation/2026-09-02-bubble-physical-input-map.md`
- `docs/validation/2026-09-07-bubble-fresh-image-emulator-regression.md`

## Gates deliberately kept open

残る17件は、過去作業の単なる再整理では閉じられない。

- active U-Boot environment/offset、実refreshとinput-to-visible latency;
- offline FAT dirty flagのread-only再検査;
- vendor artifact/Mali/source completenessのlicense・redistribution判断;
- checksum/rollback/updateの意図的fault injection;
- coverage manifestの不足fieldと、明示的に未網羅のruntime/display/audio route;
- release imageの3 cold boot、rollback、利用者RC確認、公開承認。

これらは既存の成功例を別対象へ一般化せず、必要な新規証跡が得られた時点で閉じる。
