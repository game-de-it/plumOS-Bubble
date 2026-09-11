# plumOS Bubble

plumOS Bubbleは、GKD Bubble（RK3566 / ARM64）向けのLinuxベースCFWです。
ゲーム一覧、RetroArch、PicoArch、Standaloneエミュレータ、Game Gear専用FE、
PortMaster、Pyxel、ネットワーク転送などを1つの操作体系にまとめています。

## ドキュメント

利用者向けと開発者向けを分離し、日本語版と英語版を用意しています。

- [ドキュメント索引](docs/README.ja.md)
- [ユーザー向け取扱説明書](docs/user/README.ja.md)
- [対応システム・ROMフォルダ・拡張子・エミュレータ一覧](docs/user/supported-systems.ja.md)
- [エミュレータとホットキー](docs/user/emulators.ja.md)
- [開発者向けガイド](docs/developer/README.ja.md)
- [English project overview](README.md)

## 開発クイックスタート

リリース候補のfull SD imageは、承認済みvendor入力を用意した上で次の経路から
生成します。

```sh
PLUMOS_BUBBLE_VERSION=<version> \
PLUMOS_BUBBLE_INCLUDE_CAPTURED_VENDOR_GPU=1 \
./scripts/build-bubble-frontend-probe-image.sh
```

成果物は`output/`へ生成され、Git管理されません。ROM、利用者用BIOS、save、
network credential、秘密鍵はリポジトリや公開成果物へ含めません。

## ライセンス

plumOS独自部分は[MIT License](LICENSE)です。stockOS由来の配布物はGKDの所有物で、
vendorおよび第三者componentにはそれぞれの条件が適用されます。DraSticの扱いは
plumOS MFと同じproject-approved inclusionです。

- [第三者表記](THIRD_PARTY_NOTICES.md)
- [GKD stockOS permission notice](docs/licenses/GKD-stockOS-PERMISSION-NOTICE.txt)
- [Bubble vendor runtime notice](docs/licenses/bubble-vendor-runtime-NOTICE.txt)
