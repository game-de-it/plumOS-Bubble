# 0002: vendor substrate と plumOS-owned runtime の境界

Date: 2026-09-09  
Status: Accepted

## Decision

Bubbleの通常Runtime Updateが所有するのは、p3のmanaged app-layerと、そのcomponent
manifest/checksum/journalだけとする。active config、credential、ROM、BIOS、save/state、
PortMaster/Pyxelの利用者データ、p4、SD2はdevice/user-ownedであり更新対象にしない。

次のhardware substrateはhash固定した外部入力として隔離し、通常Runtime Updateから外す。

- raw sectors 0..32767 のRockchip boot prefix
- kernel、DTB/DTBO、external initramfs、kernel module/firmwareのmatching set
- stock kernel ABIへ結合するcaptured Mali userspace
- 再配布条件が未確定なstandalone vendor runtime

System Updateはp1のinactive System slotだけを対象とし、full readback hash後にatomicな
pending metadataをcommitする。boot/kernel/DTB/module/initramfsの変更は独立recoveryが
実証されるまで通常更新へ含めず、private full-image validationだけで扱う。

## Evidence

- `docs/validation/2026-09-01-bubble-read-only-inventory.md` がpartition/path ownershipと
  stock substrateのhashを記録している。
- `docs/decisions/0001-v90s-derived-four-partition-layout.md` がp1 System A/B、p2 matching
  boot、p3 managed runtime、p4 user/update、optional SD2の役割を固定している。
- `docs/plumos-bubble-runtime-update.md` が署名、staging、journal、rollback、health gateと
  mutable data除外を規定している。
- clean image verifierはcaptured vendor artifactを含むprivate imageを
  `publishable=no`として拒否境界に置く。

## Consequences

実機から採取したバイナリが動作に必要でも、それをplumOSのsource completenessや
再配布許可と同一視しない。private hardware validationは継続できるが、license/source
identityが閉じるまで公開release gateは通らない。

live deployでは変更componentと対応metadataだけをstagingし、実機上でhash検証後に
切り替える。実機のmutable fileをhost build結果へ合わせるために上書きしない。
