#!/usr/bin/env bash
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$ROOT_DIR/scripts/lib/bubble-libretro-package-metadata.sh"
RECIPES="$ROOT_DIR/docker/plumos-bubble-core-tools/libretro-core-recipes.tsv"
FILTER="${PLUMOS_BUBBLE_CORE_FILTER:-baseline}"
OUT_ROOT="$ROOT_DIR/${PLUMOS_BUBBLE_CORES_OUT:-output/libretro-cores/bubble}"
WORK_ROOT="$ROOT_DIR/${PLUMOS_BUBBLE_CORES_WORK:-output/build/libretro-bubble}"
CORE_INFO_REPO="https://github.com/libretro/libretro-core-info.git"
CORE_INFO_REF="beb3b8bb8175f27a295bcbce922dc846f5c6362f"
CORE_INFO_ROOT="${PLUMOS_BUBBLE_CORE_INFO_ROOT:-$WORK_ROOT/libretro-core-info}"
PLUMOS_DIR="$OUT_ROOT/plumos"
COMPONENT_DIR="$PLUMOS_DIR/components/libretro-cores"

usage() {
    printf '%s\n' \
        'Usage: scripts/build-libretro-cores-bubble.sh [--filter baseline|all|ID[,ID...]] [--out-dir PATH] [--work-dir PATH]'
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --filter) FILTER="$2"; shift 2 ;;
        --out-dir) OUT_ROOT="$ROOT_DIR/$2"; shift 2 ;;
        --work-dir) WORK_ROOT="$ROOT_DIR/$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'error: unknown argument: %s\n' "$1" >&2; exit 2 ;;
    esac
done

PLUMOS_DIR="$OUT_ROOT/plumos"
COMPONENT_DIR="$PLUMOS_DIR/components/libretro-cores"

selected() {
    local id="$1"
    local class="$2"
    case "$FILTER" in
        baseline) [ "$class" = "B" ] ;;
        all) return 0 ;;
        *)
            case ",$FILTER," in
                *,"$id",*) return 0 ;;
                *) return 1 ;;
            esac
            ;;
    esac
}

rm -rf "$OUT_ROOT"
mkdir -p "$PLUMOS_DIR/cores" "$PLUMOS_DIR/info" \
    "$PLUMOS_DIR/emulator/lib" \
    "$PLUMOS_DIR/share/libretro-system" \
    "$PLUMOS_DIR/licenses" "$COMPONENT_DIR" "$WORK_ROOT"

if [ ! -d "$CORE_INFO_ROOT/.git" ] ||
   [ "$(git -C "$CORE_INFO_ROOT" rev-parse HEAD 2>/dev/null || true)" != "$CORE_INFO_REF" ]; then
    if [ ! -d "$CORE_INFO_ROOT/.git" ]; then
        rm -rf "$CORE_INFO_ROOT"
        git clone "$CORE_INFO_REPO" "$CORE_INFO_ROOT"
    fi
    git -C "$CORE_INFO_ROOT" fetch --tags --quiet origin
    git -C "$CORE_INFO_ROOT" checkout --quiet "$CORE_INFO_REF"
    git -C "$CORE_INFO_ROOT" reset --hard --quiet
    git -C "$CORE_INFO_ROOT" clean -fdx --quiet
fi
[ "$(git -C "$CORE_INFO_ROOT" rev-parse HEAD)" = "$CORE_INFO_REF" ] || {
    printf 'error: libretro-core-info did not resolve to %s\n' \
        "$CORE_INFO_REF" >&2
    exit 1
}

manifest_rows="$OUT_ROOT/core-manifest.ndjson"
: >"$manifest_rows"
core_count=0

prepare_easyrpg_dependencies() {
    local source_root="$1"
    local liblcf_root="$source_root/lib/liblcf"
    local inih_root="$source_root/lib/inih"
    local liblcf_ref="abc215345ba962a031f2b8c645f4357cf1bece85"
    local inih_ref="577ae2dee1f0d9c2d11c7f10375c1715f3d6940c"

    rm -rf "$liblcf_root" "$inih_root"
    git clone https://github.com/EasyRPG/liblcf.git "$liblcf_root"
    git -C "$liblcf_root" checkout --quiet "$liblcf_ref"
    [ "$(git -C "$liblcf_root" rev-parse HEAD)" = "$liblcf_ref" ]

    git clone https://github.com/benhoyt/inih.git "$inih_root"
    git -C "$inih_root" checkout --quiet "$inih_ref"
    [ "$(git -C "$inih_root" rev-parse HEAD)" = "$inih_ref" ]
    (
        cd "$inih_root"
        "${CC:-gcc}" -O2 -fPIC -c ini.c -o ini.o
        "${AR:-ar}" rcs libinih.a ini.o
        "${RANLIB:-ranlib}" libinih.a
    )
}

stage_core_runtime_dependencies() {
    local elf="$1"
    local path soname target package resolved_path

    while IFS= read -r path; do
        [ -f "$path" ] || continue
        soname="$(basename "$path")"
        case "$soname" in
            ld-linux-aarch64.so.1|libc.so.6|libm.so.6|libpthread.so.0|\
            libdl.so.2|librt.so.1|libEGL.so.*|libGLESv2.so.*|\
            libGL.so.*|libMali.so.*|libSDL2-2.0.so.*)
                continue
                ;;
        esac

        target="$PLUMOS_DIR/emulator/lib/$soname"
        if [ ! -f "$target" ]; then
            cp -L "$path" "$target"
            chmod 0644 "$target"
            stage_core_runtime_dependencies "$target"
        fi

        resolved_path="$(readlink -f "$path")"
        package="$(
            {
                dpkg-query -S "$path" 2>/dev/null ||
                    dpkg-query -S "$resolved_path" 2>/dev/null ||
                    true
            } |
                head -n 1 |
                cut -d: -f1
        )"
        if [ -n "$package" ] &&
           [ -f "/usr/share/doc/$package/copyright" ]; then
            install -m 0644 "/usr/share/doc/$package/copyright" \
                "$PLUMOS_DIR/licenses/easyrpg-runtime-${package}-copyright"
        fi
    done < <(
        ldd "$elf" 2>/dev/null |
            awk '/=> \/[^ ]+/ {print $3} /^[[:space:]]*\// {print $1}' |
            LC_ALL=C sort -u
    )
}

stage_core_system_assets() {
    local id="$1"
    local source_root="$2"
    local target_root

    case "$id" in
        bluemsx)
            target_root="$PLUMOS_DIR/share/libretro-system/bluemsx"
            [ -d "$source_root/system/bluemsx/Databases" ] &&
                [ -d "$source_root/system/bluemsx/Machines" ] || {
                printf 'error: blueMSX system assets are missing\n' >&2
                return 1
            }
            mkdir -p "$target_root"
            cp -a "$source_root/system/bluemsx/." "$target_root/"
            # The upstream tree contains both freely redistributable C-BIOS
            # replacements and copyrighted machine ROM dumps.  Ship only the
            # pinned C-BIOS ROMs; users provide any original machine BIOS.
            find "$target_root/Machines" -type f \
                \( -iname '*.rom' -o -iname '*.bin' \) \
                ! -path '* - C-BIOS/*' -delete
            install -m 0644 \
                "$source_root/system/bluemsx/Machines/MSX - C-BIOS/cbios.txt" \
                "$PLUMOS_DIR/licenses/bluemsx-C-BIOS-LICENSE.txt"
            printf '%s\n' "share/libretro-system/bluemsx"
            ;;
        vice_x64|vice_xvic)
            target_root="$PLUMOS_DIR/share/libretro-system/vice"
            {
                [ -f "$source_root/vice/data/C64/kernal" ] ||
                    [ -f "$source_root/vice/data/C64/kernal-901227-03.bin" ]
            } &&
                {
                    [ -f "$source_root/vice/data/VIC20/kernal" ] ||
                        [ -f "$source_root/vice/data/VIC20/kernal.901486-07.bin" ]
                } || {
                printf 'error: VICE system assets are missing\n' >&2
                return 1
            }
            mkdir -p "$target_root"
            cp -a "$source_root/vice/data/." "$target_root/"
            # VICE's source distribution contains copyrighted Commodore ROM
            # images alongside palettes, keymaps and presentation data.  Keep
            # only non-firmware support assets in the public app layer.
            find "$target_root" -type f \
                ! \( -iname '*.vkm' -o -iname '*.vjm' -o -iname '*.vpl' \
                   -o -iname '*.sym' -o -iname '*.vrs' -o -iname '*.png' \
                   -o -iname '*.svg' -o -iname '*.ttf' -o -iname '*.xml' \
                   -o -iname '*.txt' -o -iname '*.rc' -o -iname '*.ini' \
                   -o -iname '*.json' \) \
                -delete
            printf '%s\n' "share/libretro-system/vice"
            ;;
        *)
            printf '\n'
            ;;
    esac
}

core_source_binary_name() {
    local id="$1"
    local configured_name="$2"

    case "$id" in
        flycast_xtreme) printf '%s\n' flycast_libretro.so ;;
        km_duckswanstation_xtreme_amped) printf '%s\n' swanstation_libretro.so ;;
        km_mame2003_xtreme)
            printf '%s\n' km_mame2003_xtreme_amped_libretro.so
            ;;
        km_superbroswar) printf '%s\n' superbroswar_libretro.so ;;
        *) printf '%s\n' "$configured_name" ;;
    esac
}

core_info_source_id() {
    case "$1" in
        beetle_saturn) printf '%s\n' mednafen_saturn ;;
        flycast_xtreme) printf '%s\n' flycast ;;
        km_duckswanstation_xtreme_amped) printf '%s\n' swanstation ;;
        km_mame2003_xtreme) printf '%s\n' mame2003_plus ;;
        km_superbroswar) printf '%s\n' superbroswar ;;
        *) printf '%s\n' "$1" ;;
    esac
}

core_rendering() {
    case "$1" in
        flycast|flycast_xtreme|km_duckswanstation_xtreme_amped|\
        mupen64plus_next|parallel_n64|yabasanshiro)
            printf '%s\n' hardware-gles
            ;;
        *)
            printf '%s\n' software
            ;;
    esac
}

stage_core_aliases() {
    local id="$1"
    local binary_name="$2"
    local info_source="$3"
    local alias=""
    local alias_stem
    local aliases=()

    case "$id:$binary_name" in
        beetle_saturn:mednafen_saturn_libretro.so)
            alias=beetle_saturn_libretro.so
            ;;
        dosbox_pure:dosbox_pure_libretro.so)
            alias=dosbox_pure_0.9.7_libretro.so
            ;;
        puae:puae_libretro.so)
            alias=km_puae_xtreme_amped_libretro.so
            ;;
        puae2021:puae2021_libretro.so)
            alias=uae4arm_libretro.so
            ;;
    esac
    if [ -n "$alias" ]; then
        install -m 0644 "$PLUMOS_DIR/cores/$binary_name" \
            "$PLUMOS_DIR/cores/$alias"
        alias_stem="${alias%.so}"
        install -m 0644 "$info_source" \
            "$PLUMOS_DIR/info/${alias_stem}.info"
        aliases+=("$alias")
    fi
    printf '%s\n' "${aliases[@]}" |
        jq -Rsc 'split("\n") | map(select(length > 0))'
}

find_core_license() {
    local id="$1"
    local source_root="$2"
    local candidate=""

    candidate="$(
        find "$source_root" -maxdepth 4 -type f \
            \( -iname 'LICENSE' -o -iname 'LICENSE.*' -o \
               -iname 'LICENSES' -o -iname 'COPYING' -o \
               -iname 'COPYING*' -o -iname 'copyright' -o \
               -iname 'GPL*' -o -iname 'LGPL*' \) \
            -print | LC_ALL=C sort | head -n 1
    )"
    if [ -n "$candidate" ]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    for candidate in README README.txt README.md readme.txt readme.md; do
        if [ -f "$source_root/$candidate" ] &&
           grep -Eiq \
               'permission is hereby granted|redistribution and use|gnu (lesser )?general public licen[cs]e|licensed under|source form, for non-commercial|public domain|licen[cs]e agreement' \
               "$source_root/$candidate"; then
            printf '%s\n' "$source_root/$candidate"
            return 0
        fi
    done

    case "$id" in
        daphne)
            candidate="$source_root/daphne/daphne-1.0-src/daphne.h"
            ;;
        snes9x2002)
            candidate="$source_root/src/soundux.c"
            ;;
        uzem)
            candidate="$source_root/uzem_libretro.cpp"
            ;;
        *)
            candidate=""
            ;;
    esac
    [ -n "$candidate" ] && [ -f "$candidate" ] &&
        printf '%s\n' "$candidate"
}

while IFS='|' read -r id class repo ref subdir makefile make_args binary; do
    case "$id" in
        ""|\#*) continue ;;
    esac
    selected "$id" "$class" || continue

    work_dir="$WORK_ROOT/$id"
    if [ ! -d "$work_dir/.git" ]; then
        rm -rf "$work_dir"
        git clone "$repo" "$work_dir"
    fi
    git -C "$work_dir" fetch --tags --quiet origin
    git -C "$work_dir" checkout --quiet "$ref"
    git -C "$work_dir" reset --hard --quiet
    git -C "$work_dir" clean -fdx --quiet
    if [ -f "$work_dir/.gitmodules" ]; then
        git -C "$work_dir" submodule sync --recursive --quiet
        if [ "$id" = "ecwolf" ]; then
            # The three Bitbucket SDL forks are no longer publicly reachable,
            # and the libretro target only consumes libretro-common.
            git -C "$work_dir" submodule update --init --depth 1 --quiet \
                src/libretro/libretro-common
        else
            git -C "$work_dir" submodule update --init --recursive \
                --depth 1 --quiet
        fi
        git -C "$work_dir" submodule foreach --recursive \
            'git reset --hard --quiet && git clean -fdx --quiet' >/dev/null
    fi
    resolved_commit="$(git -C "$work_dir" rev-parse HEAD)"
    [ "$resolved_commit" = "$ref" ] || {
        printf 'error: %s resolved to %s, expected %s\n' \
            "$id" "$resolved_commit" "$ref" >&2
        exit 1
    }

    build_dir="$work_dir"
    [ -z "$subdir" ] || build_dir="$work_dir/$subdir"
    read -r -a build_arg_array <<<"$make_args"
    if [ "$id" = "easyrpg" ]; then
        prepare_easyrpg_dependencies "$work_dir"
    fi
    if [ "$id" = "mupen64plus_next" ]; then
        patch -d "$work_dir" -p1 \
            <"$ROOT_DIR/patches/libretro-cores-bubble/mupen64plus-next-mali-buffer-storage.patch"
    fi
    if [ "$id" = "bluemsx" ]; then
        patch -d "$work_dir" -p1 \
            <"$ROOT_DIR/patches/libretro-cores-bubble/bluemsx-cbios-safe-default.patch"
    fi
    if [ "$id" = "mba_mini" ]; then
        patch -d "$work_dir" -p1 \
            <"$ROOT_DIR/patches/libretro-cores-bubble/mba-mini-osd-debugger-stub.patch"
        patch -d "$work_dir" -p1 \
            <"$ROOT_DIR/patches/libretro-cores-bubble/mba-mini-synchronous-work-queue.patch"
    fi
    if [ "$id" = "parallel_n64" ]; then
        patch -d "$work_dir" -p1 \
            <"$ROOT_DIR/patches/libretro-cores-bubble/parallel-n64-rk3566.patch"
    fi
    if [ "$id" = "vemulator" ]; then
        patch -d "$work_dir" -p1 \
            <"$ROOT_DIR/patches/libretro-cores-bubble/vemulator-flash-writer-init.patch"
    fi
    if [ "$id" = "nekop2" ]; then
        patch -d "$work_dir" -p1 \
            <"$ROOT_DIR/patches/libretro-cores-bubble/nekop2-np2kai-bios-fallback.patch"
    fi
    if [ "$id" = "retro8" ]; then
        patch -d "$work_dir" -p1 \
            <"$ROOT_DIR/patches/libretro-cores-bubble/retro8-pico8-audio.patch"
    fi
    if [ "$id" = "yabasanshiro" ]; then
        patch -d "$work_dir" -p1 \
            <"$ROOT_DIR/patches/libretro-cores-bubble/yabasanshiro-2.10.4-arm64-gcc12.patch"
        patch -d "$work_dir" -p1 \
            <"$ROOT_DIR/patches/libretro-cores-bubble/yabasanshiro-2.10.4-vdp1-framebuffer-readback.patch"
        # The pinned source stores cd-libretro.c as CRLF. Normalize it so the
        # The CCD fix applies reproducibly in both host and container builds.
        perl -pi -e 's/\r$//' \
            "$work_dir/yabause/src/cd-libretro.c"
        patch -d "$work_dir" -p1 \
            <"$ROOT_DIR/patches/libretro-cores-bubble/yabasanshiro-2.10.4-libretro-ccd-file-size.patch"
        perl -pi -e 's/\r$//' \
            "$work_dir/yabause/src/retro_arena/main.cpp"
        patch -d "$work_dir" -p1 \
            <"$ROOT_DIR/patches/libretro-cores-bubble/yabasanshiro-2.10.4-bubble-sched-other.patch"
        if grep -Eq \
            'pthread_setschedparam\([^;]*SCHED_(FIFO|RR)' \
            "$work_dir/yabause/src/retro_arena/main.cpp" \
            "$work_dir/yabause/src/scsp.c"; then
            printf 'error: YabaSanshiro libretro still requests a realtime scheduler\n' \
                >&2
            exit 1
        fi
    fi
    if [ "$id" = "scummvm" ]; then
        patch -d "$work_dir" -p1 \
            <"$ROOT_DIR/patches/libretro-cores-bubble/scummvm-libretro-audio-clock.patch"
        (
            cd "$work_dir/backends/platform/libretro"
            make clean >/dev/null 2>&1 || true
            make -j"${JOBS:-$(nproc)}" \
                platform=unix \
                LITE=1 \
                NO_WIP=1 \
                FORCE_OPENGLNONE=1 \
                USE_MT32EMU= \
                USE_VORBIS= \
                USE_THEORADEC= \
                USE_FLUIDSYNTH= \
                USE_FREETYPE2= \
                USE_MPEG2= \
                USE_IMGUI=
        )
    elif [ "$makefile" = "CMakeLists.txt" ]; then
        cmake_args=()
        cmake_target=""
        for build_arg in "${build_arg_array[@]}"; do
            case "$build_arg" in
                target=*) cmake_target="${build_arg#target=}" ;;
                *) cmake_args+=("$build_arg") ;;
            esac
        done
        if [ "$id" = "easyrpg" ]; then
            cmake_args+=(
                "-DINIH_INCLUDE_DIR=$work_dir/lib/inih"
                "-DINIH_LIBRARY=$work_dir/lib/inih/libinih.a"
            )
        fi
        cmake_build_dir="$work_dir/build-libretro"
        cmake -S "$build_dir" -B "$cmake_build_dir" \
            -DCMAKE_BUILD_TYPE=Release \
            "${cmake_args[@]}"
        cmake_build_args=(--build "$cmake_build_dir" --parallel "${JOBS:-$(nproc)}")
        [ -z "$cmake_target" ] ||
            cmake_build_args+=(--target "$cmake_target")
        cmake "${cmake_build_args[@]}"
    else
        (
            cd "$build_dir"
            if [ "$id" = "yabasanshiro" ]; then
                # Pinned 2.10.4 documents GCC crashes for its AArch64 dynarec.
                # Keep the dynarec and GLES renderer, but compile this core
                # with the validated Clang toolchain.
                make -j"${JOBS:-$(nproc)}" -f "$makefile" \
                    "${build_arg_array[@]}" \
                    CC=clang CXX=clang++ "AS=clang -c" \
                    GIT_VERSION=-"$(printf '%s' "$ref" | cut -c 1-7)"
            else
                make -j"${JOBS:-$(nproc)}" -f "$makefile" \
                    "${build_arg_array[@]}" \
                    GIT_VERSION=-"$(printf '%s' "$ref" | cut -c 1-7)"
            fi
        )
    fi

    binary_name="$(basename "$binary")"
    source_binary_name="$(core_source_binary_name "$id" "$binary_name")"
    binary_path="$build_dir/$source_binary_name"
    if [ ! -f "$binary_path" ]; then
        binary_path="$(
            find "$work_dir" -type f -name "$source_binary_name" \
                -print | LC_ALL=C sort | head -n 1
        )"
    fi
    [ -n "$binary_path" ] && [ -f "$binary_path" ] || {
        printf 'error: %s did not produce %s (packaged as %s)\n' \
            "$id" "$source_binary_name" "$binary_name" >&2
        exit 1
    }
    info_id="$(core_info_source_id "$id")"
    info_source="$ROOT_DIR/configs/libretro/${id}_libretro.info"
    [ -f "$info_source" ] ||
        info_source="$CORE_INFO_ROOT/${info_id}_libretro.info"
    [ -f "$info_source" ] || {
        printf 'error: missing core info: %s\n' "$info_source" >&2
        exit 1
    }
    license_source="$(find_core_license "$id" "$work_dir")"
    [ -n "$license_source" ] || {
        printf 'error: no license file found for %s\n' "$id" >&2
        exit 1
    }

    install -m 0644 "$binary_path" "$PLUMOS_DIR/cores/$binary_name"
    "${STRIP:-strip}" "$PLUMOS_DIR/cores/$binary_name"
    install -m 0644 "$info_source" "$PLUMOS_DIR/info/${id}_libretro.info"
    if [ "$id" = "flycast_xtreme" ]; then
        sed -i \
            -e 's/^display_name = .*/display_name = "Sega - Dreamcast\/NAOMI (Flycast Xtreme)"/' \
            -e 's/^corename = .*/corename = "Flycast Xtreme"/' \
            "$PLUMOS_DIR/info/${id}_libretro.info"
    fi
    install -m 0644 "$license_source" "$PLUMOS_DIR/licenses/${id}-LICENSE"
    if [ "$id" = "easyrpg" ] || [ "$id" = "flycast_xtreme" ]; then
        stage_core_runtime_dependencies \
            "$PLUMOS_DIR/cores/$binary_name"
    fi
    system_asset_root="$(stage_core_system_assets "$id" "$work_dir")"
    rendering="$(core_rendering "$id")"
    binary_aliases="$(
        stage_core_aliases "$id" "$binary_name" \
            "$PLUMOS_DIR/info/${id}_libretro.info"
    )"

    runtime_libraries="$(
        find "$PLUMOS_DIR/emulator/lib" -maxdepth 1 -type f \
            -exec basename {} \; |
            LC_ALL=C sort |
            jq -Rsc 'split("\n") | map(select(length > 0))'
    )"
    package_revision="$(bubble_libretro_package_revision "$id")"
    patch_sha256="$(bubble_libretro_patch_sha256 "$id")"

    jq -cn \
        --arg id "$id" \
        --arg source "$repo" \
        --arg source_commit "$resolved_commit" \
        --arg binary "$binary_name" \
        --arg system_asset_root "$system_asset_root" \
        --arg rendering "$rendering" \
        --arg package_revision "$package_revision" \
        --arg patch_sha256 "$patch_sha256" \
        --argjson binary_aliases "$binary_aliases" \
        --argjson runtime_libraries "$runtime_libraries" \
        '{
          id:$id,
          source:$source,
          source_commit:$source_commit,
          binary:$binary,
          binary_aliases:$binary_aliases,
          rendering:$rendering,
          package_revision:$package_revision,
          patch_sha256:$patch_sha256,
          system_asset_root:$system_asset_root,
          runtime_libraries:$runtime_libraries
        }' \
        >>"$manifest_rows"
    core_count=$((core_count + 1))
done <"$RECIPES"

[ "$core_count" -gt 0 ] || {
    printf 'error: filter selected no cores: %s\n' "$FILTER" >&2
    exit 1
}

generated_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
source_ref="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || printf unknown)"
jq -s \
    --arg generated_at "$generated_at" \
    --arg source_ref "$source_ref" \
    --arg filter "$FILTER" \
    '{
      name:"plumOS Bubble libretro core set",
      component:"libretro-cores",
      device:"bubble",
      version:"1",
      architecture:"aarch64",
      rendering:"mixed",
      filter:$filter,
      source_ref:$source_ref,
      generated_at:$generated_at,
      cores:.
    }' "$manifest_rows" >"$COMPONENT_DIR/manifest.json"
rm -f "$manifest_rows"

(
    cd "$PLUMOS_DIR"
    find cores info licenses emulator/lib share/libretro-system -type f -print |
        LC_ALL=C sort |
        while IFS= read -r path; do sha256sum "$path"; done
    sha256sum components/libretro-cores/manifest.json
) >"$COMPONENT_DIR/checksums.sha256"

(
    cd "$PLUMOS_DIR"
    sha256sum -c components/libretro-cores/checksums.sha256
)
file "$PLUMOS_DIR"/cores/*_libretro.so
printf 'created: %s (%s cores, filter=%s)\n' "$OUT_ROOT" "$core_count" "$FILTER"
