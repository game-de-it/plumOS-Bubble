このファイルは、この repository で作業する Codex/agent 向けのルールです。
適用範囲は repository 全体です。

## 作業開始時

- `git status --short`、`TODO.md`、関連する `docs/`、直近の `git log --oneline` を確認する。
- 不明点はまず既存 docs、scripts、commit history、artifacts を確認する。

## プロジェクト方針

このプロジェクトではGKD Bubbleというハンドヘルドで動作するLinuxを構築することが目的になります。
作業履歴、ログはgitを使って進めましょう。

## 実装およびトラブルシューティング
- 何かを実装するに当たっては、下記ガイドを参考にして問題が起きそうな事柄に対して事前に対処すること
plumOS_gitlog_problem_solution_guide.ja.md
- トラブルシューティングする際にもガイドの内容を参考にすること

## フロントエンド互換性

- 他のplumOSシリーズに存在する共通メニュー項目を、Bubble側で未実装であることを理由に
  削除してはならない。共通の並びと項目を表示したまま、未実装の機能は選択時に
  `未実装`または`未対応`を明示し、対応TODOへ追跡可能にする。
- 共通runtime catalogに含まれるsystem、emulator、core、launch profileを、個別移植が
  未完了であることを理由に一覧や検証対象から削除してはならない。実行可能な導線を
  提供するか、機種固有の未対応理由を機械可読なcoverage表とFE上の状態表示へ残す。
- release gateでは、package済みcoreの全てがFE導線または明示的な未対応表示へ到達すること、
  FEが公開する全導線が実在するlauncher/coreへ解決することを双方向に検証する。
- 実装済み項目を減らす変更では、同等機能への置換、移行経路、実機acceptanceが揃うまで
  既存項目を保持する。

## 実機デプロイ

- `/mnt/plumos` 配下の app-layer 管理ファイルを実機へ更新する場合は、
  バイナリやライブラリだけを単独でデプロイしてはならない。対応する
  `checksums.sha256` を必ずデプロイに含め、`manifest.json`、必要な
  component manifest も同じデプロイ単位で整合させる。
- 再起動前に実機上でデプロイ対象の SHA-256 と app-layer checksum 検証を
  実行し、bootstrap が更新ファイルを `critical checksum failed` として
  拒否しないことを確認する。
- 実機側で変更されたユーザー設定、PortMaster 更新物、セーブデータなどを
  ホスト側の app-layer metadata に合わせる目的で上書きしてはならない。
  ライブデプロイでは変更対象の管理ファイルと、その metadata entry だけを
  原子的に更新する。
- ssh接続のユーザ名とパスワードのデフォルトはroot/plumosである
