# plumOS-Bubble third-party notices

The repository `LICENSE` applies to plumOS-Bubble-authored software and
documentation unless a file or component states otherwise. It does not
relicense vendor firmware, proprietary binaries, third-party libraries,
emulators, fonts, firmware or other separately authored material.

## GKD stockOS-derived material

plumOS-Bubble was initially developed with reference to the publicly available
[plumOS-GKD stockOS image](https://github.com/game-de-it/plumOS-GKD), including
the GKD Bubble / MINIPLUS BBG v5.3 hardware runtime.

The project maintainer attests that the GKD Bubble vendor granted permission to
use and redistribute the stockOS-derived files required by plumOS-Bubble. No
separate written license file was issued for that permission. The stockOS
distribution and GKD-authored material remain the property of GKD and are not
covered by the plumOS-Bubble MIT License. Copyrights and license terms in
third-party material contained in stockOS, including Arm Mali software, remain
with their respective owners.

The exact captured artifacts, hashes and build boundary are recorded in
`configs/bubble-vendor-artifacts.json` and
`docs/licenses/bubble-vendor-runtime-NOTICE.txt`.

## DraStic

The steward-fu/nds integration source is licensed under LGPL-2.1-only. The
DraStic executable is a separately authored proprietary emulator and is not
relicensed under LGPL or MIT. In line with the plumOS-MF release policy, the
pinned DraStic executable is a narrowly approved release inclusion, and its
integration license, upstream release README, provenance and DraStic notice
must accompany every distribution.

See `docs/licenses/drastic-upstream-NOTICE.txt` for the complete project policy.

## Other components

Other packaged components retain their upstream licenses. The generated System
and app-layer place the applicable license and notice material under
`/usr/share/licenses` and `/mnt/plumos/licenses` respectively.
