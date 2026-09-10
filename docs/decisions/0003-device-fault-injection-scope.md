# Device fault-injection scope

Date: 2026-09-10

## Decision

Bubbleのrelease acceptanceでは、実機SDの管理領域へ意図的な破損、容量枯渇、書込み中断、
bad slot、health failureを注入する試験を必須条件にしない。他のplumOSシリーズと同じ範囲に
揃え、通常のwrite/readback、cold boot、update、rollback、recovery、shutdownを実機で確認する。

異常系の実装を削除する判断ではない。checksum不一致、署名不一致、容量不足、journal中断、
health failure、downgradeの拒否とrollbackは、再現可能でユーザーデータを危険にさらさないhost
fixtureで検証し続ける。通常更新と旧version拒否は`BUB-P7-01`、matching-set updateとrecoveryは
`BUB-P7-02`、最終image/hardware acceptanceは`BUB-P7-06`で追跡する。

## Rationale

意図的な実機fault injectionは、ROM、BIOS、save、設定、資格情報や起動可能なSDを毀損する
可能性がある。一方、Bubbleだけにこの試験をrelease gateとして要求すると、他シリーズとの
acceptance基準が不必要にずれる。通常経路の実機証跡と異常経路のhost fixtureを分離することで、
共通基準を保ちながらfail-safeの回帰検出を維持する。
