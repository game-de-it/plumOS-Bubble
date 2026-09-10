# 0004: Bubble vendor runtime publication boundary

Date: 2026-09-10  
Status: Accepted

## Decision

Bubbleのvendor入力を`configs/bubble-vendor-artifacts.json`へ固定し、Git外の
`artifacts/vendor/bubble-stock-source`に隔離する。通常のprivate実機検証ではexact hashの
入力だけを許可し、公開release gateでは`private-validation-only`入力を1件でも含む成果物を
拒否する。

MaliはAArch64/ARMhfともuserspace DDK `g13p0-01eac0`、preserved kernelは
`g2p0-01eac0`で一致しない。別の公開g13p0 GBM binaryともsize/hashが一致しなかった。
一方、このexact pairはPPSSPP、DraStic、Pyxel、PortMasterを含む実機経路で動作済みである。
したがってABIを「一般的なg13p0互換」とは扱わず、kernelを含むexact compatibility setとして
private検証へ採用し、別binaryへの置換は禁止する。

公開Rockchip libmali collectionに同梱されるARM EULAは、条件付きでMali userspaceの配布を
許可している。しかし、そのEULAが今回stock OSから採取したexact binaryへ添付・適用された
ことを示す根拠は見つからなかったため、再配布可能とは判定しない。

DraSticは`steward-fu/nds`のpinned release assetから取得できるが、LGPL-2.1はintegration
sourceを対象とし、別著作者のclosed executableを再licenseしない。別個の再配布許諾が確認
できないため、これもprivate検証だけに限定する。

## Consequences

- `BUB-P3-02`のhash、source identity、license status、capture procedureを機械可読に固定した。
- `BUB-P4-D05`はMaliをexact pairとして隔離採用し、公開配布には不採用と決定した。
- 現行のfull-stack imageは機能確認用private imageのままである。
- `BUB-P7-05`を閉じるには、公開版からprivate入力を除外して該当FE routeを明示的な未対応表示へ
  変えるか、exact artifactへ適用できる再配布根拠を追加する必要がある。

これは法的助言ではなく、根拠が不足したartifactを公開しないためのproject release policyである。

## Evidence

- 実機boot log: kernel DDK `g2p0-01eac0`
- captured Mali strings: userspace `1.4 Bifrost-g13p0-01eac0`
- AArch64: 43,489,296 bytes, SHA-256
  `56e37253ef3c217932aa947734399203614dfa6046a077444d4c76fd29ea5be2`
- ARMhf: 42,431,936 bytes, SHA-256
  `bbe45b17ec872897a0039a685ba25e87ea8fa2244f3a36648c37acf9fdb55d34`
- DraStic archive SHA-256
  `9e4ed98047dea0f014daea7c3530793f92f19d60073fceb9fd2a040696f66491`
- `scripts/audit-bubble-vendor-artifacts.py` verifies the ignored local captures when present and
  always fails under `--require-publishable` while private inputs remain.
