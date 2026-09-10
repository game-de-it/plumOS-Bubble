# Bubble Java ME unsupported decision

Date: 2026-09-10

## Decision

GKD BubbleではJava MEを動作対象外とする。`systems.json`の`j2me`は`enabled=false`かつ
`support.state=unsupported`とし、通常FEのsystem一覧、ROM scan、実機runtime matrixへ公開しない。
SquirrelJME profileとpackage済みcoreの記録は、共通plumOS catalogとの対応関係を失わないため
内部metadataに保持する。

## Evidence

- ROM2の`Cento.jar`はFE導線から起動したが、SquirrelJMEが`Init -7` / `JVM Exec Error -7`で停止した。
- 同じ固定source commitから構築したupstream同梱ゲーム`Squirrel Quarrel`でも、BootRAMを与えた後に
  `Failed to initialize the BootRAM` / `Init -8`となりcontent実行へ到達しなかった。
- package対象の固定commitは`/storage/BIOS/squirreljme.sqc`をBootRAMとして要求するが、対応する
  SummerCoat BootRAM生成経路はupstream AOT minimizerの`INCOMPLETE CODE`で構築できない。
- 同commitのmedia APIは`NullPlayer`を返し、`Manager.playTone()`も未実装である。したがって起動だけを
  迂回しても、今回のacceptance対象であるJava ME音声を提供できない。

## Regression gate

`scripts/verify-bubble-emulator-catalog.sh`は、`j2me`が無効、非対応理由付き、scraper非対象であることと、
内部profileが`retroarch:squirreljme`へ追跡可能なことを検証する。
