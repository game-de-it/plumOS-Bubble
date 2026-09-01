# plumOS Bubble porting plan

作成日: 2026-09-01  
対象機種: GKD Bubble / RK3566  
初回実機根拠: `docs/validation/2026-09-01-bubble-read-only-inventory.md`

## Goal

GKD Bubble で、再現可能に build でき、stock/CFW のユーザーデータを壊さず、失敗時に
複製 SD の交換で復旧できる plumOS を構築する。kernel source がないため、動作中 CFW と
その SD から採取した artifact を provenance、hash、再配布条件付きの入力として管理する。

最初の成功条件は多数の emulator ではなく、次の一経路を閉じることである。

```text
recovery-capable boot -> plumOS System -> frontend -> NES/QuickNES
  -> input + audio + save -> clean exit -> exactly one frontend
```

## Non-negotiable boundaries

1. 現在動作中の OS SD、ROM SD、ROM、BIOS、save、credential、active setting を変更しない。
2. block device の調査、image 化、filesystem 検査は最初に read-only で行う。
3. 実験はhostで検証したseed imageを書いた新SDだけで行い、original OS SDへ書かない。
4. raw boot prefix、U-Boot、kernel、DTB、initrd は一致する一組として扱い、単独更新しない。
5. `/storage` の device-owned data を host metadata に合わせて上書きしない。
6. live app-layer deploy は binary/library、`checksums.sha256`、`manifest.json`、component
   manifest の整合した単位で行い、対象 metadata entry だけを原子的に更新する。
7. boot/runtime failure 時も log と recovery SSH を残し、stock UI へ無言で fallback しない。
8. OS SD/ROM SD の device number を固定せず、partition identity と mount source で解決する。
9. host build、SSH 上の起動、物理表示・入力・音声・終了は別の acceptance として記録する。
10. artifact 生成と release 公開を分け、公開は利用者の明示確認後にだけ行う。

## Reference matrix

| Reference | Reuse | Do not copy |
| --- | --- | --- |
| `plumOS-MF` | RK3566/RK817、640x480 DRM probe、software KMS baseline、runtime isolation | MF boot hook、input daemon、path/device values |
| `plumOS-pixel2_v2` | stock substrate + plumOS System、first boot、app-layer/update ownership | RK3326S DTB、rotation、USB policy、partition sizes |
| `plumOS-V90S_v2-public` | vendor artifact provenance、clean-clone build、signed update/A-B | Allwinner boot/kernel、PowerVR runtime |
| `plumOS-XU20V32` | boot prefix保全、matching System+Kernel update、physical acceptance | A133 layout、kernel config、display helpers |
| `plumOS-A30` / `plumOS-MMF` | reversible entry、device backend、user-config preservation | MainUI hook、vendor display/input values |

## Adopted storage direction and provisional boot implementation

V90Sの4 partition ownershipとtransactional update contractをBubbleにも採用する。
詳細と未確定gateは`docs/decisions/0001-v90s-derived-four-partition-layout.md`に記録した。

初回観測では、OS SD は raw Rockchip boot prefix + FAT boot partition + ext4 storage で、
FAT 上の `SYSTEM` SquashFS が `/` へ loop mount される。最終候補は次である。

```text
raw 16 MiB exact Rockchip prefix
  -> p1 PLUMBOOT: boot resources + signed System A/B
  -> p2 BOOT: matching kernel + DTB + initramfs/recovery bundle
  -> p3 PLUMOS_SYS: ext4 managed runtime/state/rollback
  -> p4 PLUMOS: FAT32 user content/update/logs
  -> optional SD2: ROM/BIOS/media, not required for boot/update
```

roleとupdate ownershipは採用済みだが、p1/p2/p3の正確な容量、p2 raw format、MBR/GPTは
provisionalである。Bubble U-Bootのload/recoveryを複製SDで証明するまでは、現CFWと同じ
p1 file bootを維持する。V90Sの物理sizeやAllwinner boot imageはコピーしない。

## Phase 0: repository and safety baseline

Deliverables:

- Git repository、`TODO.md`、本計画、日付付き validation record
- artifact/output を Git から除外する policy
- stock OS SD と ROM SD の preserved/mutable/unknown 表
- 現 OS SD を抜かずに復旧できることを前提にした clone-card procedure

Gate:

- 変更前の実機状態と未確認事項が文書化されている。
- ROM/BIOS/save/credential を build input に含めない。
- 実機への write を伴う次工程は、利用者が複製 SD を用意してから開始する。

## Phase 1: exact boot artifact capture and rollback

1 SD reader環境では、稼働中stock OSからSSHでbounded boot substrateをread-only captureする。
必要に応じてoriginal OS SDをmacOSへ接続し、offline full recovery imageを別工程で採取する。

Deliverables:

- physical size、sector size、MBR/partition/LBA map、unpartitioned gap の記録
- SD 全体または boot に必要な bounded region の sector image と SHA-256
- raw prefix、U-Boot、environment、`Image`、`SYSTEM`、全 DTB/DTBO、boot scripts の hash manifest
- `/proc/device-tree` から採取した runtime DTB と selected file DTB の比較
- kernel config、module/firmware、vendor Mali userspace の ABI/provenance inventory
- host seed imageと新SDのimage-size全block readback verification
- known-good SD への戻し方と serial/SSH/log recovery route
- V90S由来4 partition candidateのp1 A/B capacity計算、p2 boot形式、p3 seed/target、
  p4/SD2 ownershipの確定

Gate:

- original SD に書かず、複製 SD が同じ CFW で cold boot する。
- LCD、controller、audio、Wi-Fi、SSH、ROM SD mount が clone で維持される。
- raw prefixを含む再現入力とhashが揃い、別SDへ復元可能である。

## Phase 2: boot ownership probe

複製 SD 上だけで、既存 `SYSTEM` を変更せず、boot handoff の各段階を計測する。

```text
Boot ROM -> IDBLoader/SPL -> U-Boot -> Image -> initrd/early init
  -> /flash/SYSTEM loop mount -> systemd -> launcher -> EmulationStation
```

Deliverables:

- U-Boot serialまたはFAT log、kernel early log、systemd milestone
- boot partition selection、root UUID、fallback、environment location の証明
- plumOS diagnostic System slotを選ぶ可逆な one-shot probe
- visible success/error marker と recovery SSH
- stock/CFW service、device、library ownership table

Gate:

- probe failure でも clone を差し戻せる。
- stock frontendを開始せず、plumOS diagnostic processがforegroundで保持される。
- display/input/audio device ownerとmount sourceが記録される。

## Phase 3: minimal plumOS System

Bubble 向け AArch64 System を clean container から再現 build する。

Deliverables:

- read-only SquashFS System A/B と atomic slot metadata
- writable `/run`、`/tmp`、device-owned persistent data の明示 mount
- plumOS supervisor、log、checksum failure screen、SSH recovery
- component-scoped loader/library path。global `LD_LIBRARY_PATH` は使用しない
- Bubble device identity と root/app-layer manifest

Gate:

- stock kernel/PID 1/handoff と plumOS-owned runtime の境界が `/proc/*/maps` で説明できる。
- intentional checksum failure が error screen と SSH を維持する。
- `SYSTEM`、app-layer、user data の owner が混ざらない。

## Phase 4: Bubble hardware profile

小さな read-only probe を先に作り、物理確認後に control helper を実装する。

1. Display: DSI 640x480、format/stride、DRM plane/CRTC、実 refresh、page-flip completion
2. Input: 全 button、analog、power、GPIO key、G-sensor、rumble、press/release、hotkey
3. Audio: RK817 speaker/headphone、jack、safe gain、rate、5分継続、XRUN
4. Power: backlight 0..255、battery/charger、shutdown、reboot、charge-only、suspend/resume
5. Network/USB: AP6330 ownership、Wi-Fi persist/recovery、USB host/device/charging conflict
6. Storage: OS SD/ROM SD identity、dirty media handling、clean unmount

Gate:

- 各 helper が `probe`/`status` と bounded error を持つ。
- physical result が日付付き validation に記録される。
- unsupported 機能は `N/A` とし、他機種 helper へ fallback しない。

## Phase 5: frontend and one-game baseline

初期 frontend は CPU-rendered DRM/KMS double buffer を優先する。vendor Mali は必要になるまで
plumOS global dependency にしない。

Deliverables:

- Bubble 640x480 profile と connected connector/mode の runtime discovery
- one input owner と確定済み mapping
- RK817 audio route
- RetroArch + QuickNES + 利用者提供の1本のNES test content
- save/state と frontend return lifecycle

Gate:

- FE、RA menu、game の向き、aspect、色、scroll、音が物理確認済み。
- A/B/D-pad/START/SELECT/menu/exit が1入力1反応である。
- game終了後に frontend がちょうど1 process、device owner残留なし。
- save/state が reboot 後も保持される。

## Phase 6: GPU and wider runtime decision

順序:

1. software DRM/KMS で FE と軽量 core を成立させる。
2. 既存 plumOS AArch64 component を Bubble ABI で個別検証する。
3. vendor `libmali` の license、redistribution、kernel DDK compatibility を監査する。
4. Mesa/Panfrost は vendor 4.19 kernel との適合を調べ、kernel replacement を前提にしない。
5. vendor GPU が必要な standalone/PortMaster は明示 component に隔離する。

Gate:

- software path と vendor GPU path の ownership が混ざらない。
- SDL/EGL/GLES loader と mapped library が component manifest と一致する。
- frontend、RetroArch、代表 standalone、Pyxel、PortMaster の採否理由が記録される。

## Phase 7: storage, lifecycle and updates

| Class | Bubble policy |
| --- | --- |
| immutable boot | raw prefix、U-Boot、kernel、DTB、initrdをmatching setで保持・更新 |
| immutable System | signed A/B file、readback、health、rollback |
| managed app layer | component manifest + checksum、atomic deploy |
| mutable config | active settingは保持し、factory defaultと分離 |
| user media | ROM、BIOS、save、state、screenshot、credentialはupdate対象外 |

試験には normal update だけでなく、tamper、downgrade、disk full、中断、bad slot、health failure、
old public version からの cumulative update を含める。power test は charger 接続前後、cold/warm、
suspend/resume、clean filesystem を独立して確認する。

## Phase 8: release acceptance

1. clean clone から全 artifact を build
2. source lock、license、secret/ROM/BIOS 混入検査
3. image/archive/checksum/manifest の host verification
4. SD write後のblock readback
5. clone SD で cold boot 3回、warm reboot、failure rollback
6. display/input/audio/save/exit、5分継続、sleep/charge/network/shutdown
7. old version からの signed update と rollback
8. release candidate を利用者が実機確認
9. 明示承認後だけ公開し、公開 asset を再downloadして checksum 確認

## Evidence format

各完了項目は次を残す。

```text
Context: 実機で観測した条件と症状
Cause: log/hash/A-B testから確定した原因
Changed: 変更したownership境界
Preserved: 変更しなかったboot/user data
Verified: host/build/deploy/readback/physicalを分離
Remaining: 未確認の物理経路
```
