#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
script=$repo_root/scripts/build-standalone-bubble.sh
pcsx_script=$repo_root/scripts/build-pcsx-rearmed-bubble.sh
yabasanshiro_script=$repo_root/scripts/build-yabasanshiro-bubble.sh
drastic_script=$repo_root/scripts/build-drastic-bubble.sh

grep -Fq 'if [[ ${1:-} != --inside ]]; then' "$script"
grep -Fq 'plumos-bubble-core-tools:dev' "$script"
grep -Fq 'source_epoch="${SOURCE_DATE_EPOCH:-$(' "$script"
grep -Fq -- '-e SOURCE_DATE_EPOCH="$source_epoch"' "$script"
grep -Fq -- '-v "$ROOT_DIR:/work" -w /work "$TOOLS_IMAGE"' "$script"
grep -Fq -- '-e PLUMOS_BUBBLE_INCLUDE_CAPTURED_VENDOR_GPU=' "$script"
grep -Fq -- '--assemble-only) ;;' "$script"

assembly_line=$(grep -nF 'OUT_ROOT="$ROOT_DIR/${PLUMOS_BUBBLE_STANDALONE_OUT:-output/standalone/bubble}"' "$script" | cut -d: -f1)
for builder in \
    build-pcsx-rearmed-bubble.sh \
    build-yabasanshiro-bubble.sh \
    build-drastic-bubble.sh \
    build-ppsspp-bubble.sh \
    build-openbor-bubble.sh; do
    line=$(grep -nF '"$ROOT_DIR/scripts/'"$builder"'"' "$script" | cut -d: -f1)
    test -n "$line"
    test "$line" -lt "$assembly_line"
done

grep -Fq 'PREFIX="$SDL12_ROOT/install-bubble/"' "$pcsx_script"
grep -Fq -- '-DCMAKE_C_COMPILER=gcc' "$yabasanshiro_script"
grep -Fq -- '-DCMAKE_CXX_COMPILER=g++' "$yabasanshiro_script"
! grep -Fq -- '-DCMAKE_C_COMPILER=clang' "$yabasanshiro_script"
grep -Fq 'COMMON_SHA256="$(sha256sum "$SOURCE_LIB_ROOT/libcommon.so"' "$drastic_script"
grep -Fq 'DETOUR_SHA256="$(sha256sum "$SOURCE_LIB_ROOT/libdtr.so"' "$drastic_script"
grep -Fq 'SDL2_SHA256="$(sha256sum "$SOURCE_LIB_ROOT/libSDL2-2.0.so.0"' "$drastic_script"
grep -Fq -- '-path "$OVERLAY_DIR/usr/work" -prune' "$drastic_script"

printf '%s\n' 'bubble_standalone_clean_build=result-ok builders=5 containerized=1'
