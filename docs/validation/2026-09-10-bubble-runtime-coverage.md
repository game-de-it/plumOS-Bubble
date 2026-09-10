# Bubble runtime coverage manifest validation

Date: 2026-09-10

## Scope

`BUB-P6-05`で要求するBIOS、content extension、renderer、loader/library、license、save/state
ownershipを、frontendの各launch profile occurrenceへ機械可読に固定した。物理的な全route実行は
このmanifest作成と混同せず、`BUB-P6-10`で追跡する。

## Source and generation

`scripts/generate-bubble-runtime-coverage.py`は次を入力にする。

- `config/frontend/systems.json`: system、alias、extension、default、launch profile
- `components/libretro-cores/manifest.json`: source core、binary alias、renderer
- `components/standalone/manifest.json`: standalone binary、renderer
- `info/*_libretro.info`: core対応extension、BIOS、license、save/state capability
- app-layer内のbinaryとlicense evidence

生成物は`package/frontend-bubble/plumos/config/frontend/runtime-coverage.json`へschema 2として固定する。
実機のROM、BIOS、save、state、設定は入力にせず、hashや一覧も収録しない。

## Result

`tests/test-bubble-runtime-coverage.sh`はビルド済みapp-layerから一時manifestを再生成し、checked-in
manifestとbyte単位で比較した。その後、catalogとartifactの双方向検証を実行した。

同日後続のBubble機種固有判断により、可視unsupportedだった3DSをcatalogとscanから除外した。
以下はその判断を反映した現在の97-system contractであり、196 route自体は変わらない。

```text
bubble_picoarch_rgb565_matrix=result-ok routes=20 rgb565=18 core_byteswap=6 route_overrides=5 xrgb8888=2 compat=1
bubble_emulator_catalog=result-ok systems=97 profiles=196 retroarch_ids=116 picoarch_ids=20 standalone_ids=5 release_complete=no
bubble_runtime_coverage=result-ok systems=97 profiles=196 core_records=114
```

196 routeのlicense状態はpackaged 194、DraSticのproject-approved-inclusion 1、PortMasterの
runtime-managed/per-port 1。BIOS policyはnone 78、optional 95、required 21、DraSticの
packaged-with-user-override 1、PortMasterのport-specific 1である。vendor/Mali/DraSticのlicense
boundaryはNOTICEとallowlistで解消したが、P7-05からP7-08のrelease gateが残るため
`release_complete=false`を維持する。
