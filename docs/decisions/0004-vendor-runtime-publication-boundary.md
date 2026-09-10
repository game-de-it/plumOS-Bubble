# 0004: Bubble vendor runtime publication boundary

Date: 2026-09-10  
Status: Amended 2026-09-10 by maintainer vendor-permission attestation

## Decision

Bubbleのvendor入力を`configs/bubble-vendor-artifacts.json`へ固定し、Git外の
`artifacts/vendor/bubble-stock-source`に隔離する。buildはexact hashの入力だけを許可する。
project maintainerは、公開済みplumOS-GKD stockOSを自身が作成し、GKD Bubble vendorから
stockOS由来物をplumOS-Bubbleで利用・再配布する許可を得ているとattestした。個別の書面license
fileは発行されていない。このattestationと必須NOTICEを公開release gateの根拠として記録する。

MaliはAArch64/ARMhfともuserspace DDK `g13p0-01eac0`、preserved kernelは
`g2p0-01eac0`で一致しない。別の公開g13p0 GBM binaryともsize/hashが一致しなかった。
一方、このexact pairはPPSSPP、DraStic、Pyxel、PortMasterを含む実機経路で動作済みである。
したがってABIを「一般的なg13p0互換」とは扱わず、kernelを含むexact compatibility setとして
採用し、別binaryへの置換は禁止する。配布時はGKD stockOS permission/ownership noticeと、
該当する第三者条件を保持する。

公開Rockchip libmali collectionに同梱されるARM EULAは、条件付きでMali userspaceの配布を
許可している。しかし、そのEULAが今回stock OSから採取したexact binaryへ添付・適用された
ことを示す根拠は見つからなかった。そのため、このreference EULA単独を根拠にはせず、GKD
vendor permissionのattestationをexact stockOS captureの配布根拠とする。これはArmその他の
第三者権利をMITへ変更するものではない。

DraSticは`steward-fu/nds`のpinned release assetから取得できる。LGPL-2.1はintegration sourceを
対象とし、別著作者のclosed executableを再licenseしない。plumOS-MFと同じく、DraStic本体だけを
狭く`project-approved inclusion`へallowlistする。integration LGPL、upstream README、exact
provenance、DraStic専用NOTICEを全releaseへ残す。

## Consequences

- `BUB-P3-02`のhash、source identity、license status、capture procedureを機械可読に固定した。
- `BUB-P4-D05`はMaliをexact pairとして隔離採用し、GKD/upstream notice付きの公開対象とする。
- plumOS-Bubble独自部分はroot `LICENSE`のMIT、stockOS由来物はGKD/vendor/upstream terms、
  DraStic本体はproject-approved inclusionとして相互にrelicenseしない。
- `--require-publishable`は必須NOTICE、明示allowlist、private input不在を検証する。
- `BUB-P7-05`のlicense blockerは解消したが、clean-clone source completenessと
  secret/ROM/BIOS content gateは別途完了させる必要がある。

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
- `scripts/audit-bubble-vendor-artifacts.py` verifies the ignored local captures when present,
  requires all notices, narrowly allowlists DraStic, and fails under `--require-publishable` if a
  private-only input is reintroduced.
