#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$ROOT_DIR/scripts/lib/bubble-libretro-package-metadata.sh"
RECIPES="$ROOT_DIR/docker/plumos-bubble-core-tools/libretro-core-recipes.tsv"
FILTER="${PLUMOS_BUBBLE_CATALOG_FILTER:-all}"
OUT_ROOT="$ROOT_DIR/${PLUMOS_BUBBLE_CATALOG_OUT:-output/libretro-cores/bubble-all}"
WORK_ROOT="$ROOT_DIR/${PLUMOS_BUBBLE_CATALOG_WORK:-output/build/libretro-bubble-catalog}"
CORE_INFO_ROOT="$WORK_ROOT/libretro-core-info"
CORE_INFO_REPO="https://github.com/libretro/libretro-core-info.git"
CORE_INFO_REF="beb3b8bb8175f27a295bcbce922dc846f5c6362f"
HOST_JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"
CONCURRENCY="${PLUMOS_BUBBLE_CORE_BUILD_CONCURRENCY:-4}"
FAIL_ON_CORE_ERROR="${FAIL_ON_CORE_ERROR:-1}"
REUSE_EXISTING="${PLUMOS_BUBBLE_CORE_REUSE_EXISTING:-1}"
ADOPT_EXISTING=0
REBUILD_IDS=""
TOOLCHAIN_IMAGE="${PLUMOS_BUBBLE_DOCKER_IMAGE:-plumos-bubble-core-tools:dev}"
CACHE_SCHEMA="bubble-libretro-package-v1"

usage() {
    printf '%s\n' \
        'Usage: scripts/build-libretro-core-catalog-bubble.sh [--filter all|ID[,ID...]] [--out-dir PATH] [--work-dir PATH] [--concurrency N] [--rebuild ID[,ID...]] [--adopt-existing] [--fresh]'
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --filter) FILTER="$2"; shift 2 ;;
        --out-dir) OUT_ROOT="$ROOT_DIR/$2"; shift 2 ;;
        --work-dir) WORK_ROOT="$ROOT_DIR/$2"; shift 2 ;;
        --concurrency) CONCURRENCY="$2"; shift 2 ;;
        --rebuild) REBUILD_IDS="$2"; shift 2 ;;
        --adopt-existing) ADOPT_EXISTING=1; shift ;;
        --fresh) REUSE_EXISTING=0; shift ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'error: unknown argument: %s\n' "$1" >&2; exit 2 ;;
    esac
done

case "$HOST_JOBS:$CONCURRENCY" in
    *[!0-9:]*|0:*|*:0)
        printf 'error: jobs and concurrency must be positive integers\n' >&2
        exit 2
        ;;
esac

per_core_jobs=$((HOST_JOBS / CONCURRENCY))
[ "$per_core_jobs" -gt 0 ] || per_core_jobs=1
case "$OUT_ROOT" in
    "$ROOT_DIR"/*) ;;
    *) OUT_ROOT="$ROOT_DIR/$OUT_ROOT" ;;
esac
case "$WORK_ROOT" in
    "$ROOT_DIR"/*) ;;
    *) WORK_ROOT="$ROOT_DIR/$WORK_ROOT" ;;
esac
CORE_INFO_ROOT="$WORK_ROOT/libretro-core-info"

selected() {
    local id="$1"
    local class="$2"
    case "$FILTER" in
        all) return 0 ;;
        *)
            case ",$FILTER," in
                *,"$id",*) return 0 ;;
                *) return 1 ;;
            esac
            ;;
    esac
}

ids=()
while IFS='|' read -r id class _; do
    case "$id" in
        ""|\#*) continue ;;
    esac
    selected "$id" "$class" && ids+=("$id")
done <"$RECIPES"
[ "${#ids[@]}" -gt 0 ] || {
    printf 'error: filter selected no cores: %s\n' "$FILTER" >&2
    exit 1
}

if [ "$REUSE_EXISTING" -eq 0 ]; then
    rm -rf "$OUT_ROOT"
else
    rm -rf "$OUT_ROOT/plumos" "$OUT_ROOT/logs" "$OUT_ROOT/status"
fi
mkdir -p "$OUT_ROOT/per-core" "$OUT_ROOT/logs" "$OUT_ROOT/status" "$WORK_ROOT"
if ! docker image inspect "$TOOLCHAIN_IMAGE" >/dev/null 2>&1; then
    "$ROOT_DIR/scripts/build-bubble-core-tools-image.sh"
fi
TOOLCHAIN_IMAGE_ID="$(
    docker image inspect --format '{{.Id}}' "$TOOLCHAIN_IMAGE"
)"

recipe_row() {
    local id="$1"
    awk -F'|' -v wanted="$id" \
        '$1 == wanted { print; exit }' "$RECIPES"
}

fingerprint_for() {
    local id="$1"
    local row patch_hash package_revision
    row="$(recipe_row "$id")"
    package_revision="$(bubble_libretro_package_revision "$id")"
    patch_hash="$(bubble_libretro_patch_sha256 "$id")"
    printf '%s\n%s\n%s\n%s\n%s\n%s\n' \
        "$CACHE_SCHEMA" "$TOOLCHAIN_IMAGE_ID" "$CORE_INFO_REF" \
        "$package_revision" "$patch_hash" "$row" |
        sha256sum |
        awk '{ print $1 }'
}

forced_rebuild() {
    local id="$1"
    case ",$REBUILD_IDS," in
        *,"$id",*) return 0 ;;
        *) return 1 ;;
    esac
}

validate_existing() {
    local id="$1"
    local just_built="${2:-0}"
    local core_out="$OUT_ROOT/per-core/$id"
    local core_root="$core_out/plumos"
    local expected_ref expected_fingerprint recorded_fingerprint
    local expected_package_revision expected_patch_sha256
    local recorded_package_revision recorded_patch_sha256 binary alias

    if [ "$just_built" -eq 0 ]; then
        [ "$REUSE_EXISTING" -eq 1 ] || return 1
        forced_rebuild "$id" && return 1
    fi
    [ -f "$core_root/components/libretro-cores/checksums.sha256" ] &&
        [ -f "$core_root/components/libretro-cores/manifest.json" ] ||
        return 1

    expected_ref="$(recipe_row "$id" | awk -F'|' '{ print $4 }')"
    binary="$(
        jq -r --arg id "$id" --arg ref "$expected_ref" '
          if (.cores | length) == 1 and
             .cores[0].id == $id and
             .cores[0].source_commit == $ref
          then .cores[0].binary
          else empty
          end
        ' "$core_root/components/libretro-cores/manifest.json"
    )"
    [ -n "$binary" ] && [ -f "$core_root/cores/$binary" ] || return 1
    while IFS= read -r alias; do
        [ -z "$alias" ] || [ -f "$core_root/cores/$alias" ] || return 1
    done < <(
        jq -r '.cores[0].binary_aliases[]? // empty' \
            "$core_root/components/libretro-cores/manifest.json"
    )
    (
        cd "$core_root"
        sha256sum -c components/libretro-cores/checksums.sha256 >/dev/null
    ) || return 1

    expected_package_revision="$(bubble_libretro_package_revision "$id")"
    expected_patch_sha256="$(bubble_libretro_patch_sha256 "$id")"
    recorded_package_revision="$(
        jq -r '.cores[0].package_revision // empty' \
            "$core_root/components/libretro-cores/manifest.json"
    )"
    recorded_patch_sha256="$(
        jq -r '.cores[0].patch_sha256 // empty' \
            "$core_root/components/libretro-cores/manifest.json"
    )"
    [ "$recorded_package_revision" = "$expected_package_revision" ] &&
        [ "$recorded_patch_sha256" = "$expected_patch_sha256" ] ||
        return 1

    case "$id" in
        easyrpg)
            [ -f "$core_root/emulator/lib/libfmt.so.9" ] || return 1
            ;;
        bluemsx)
            [ -d "$core_root/share/libretro-system/bluemsx/Databases" ] &&
                [ -d "$core_root/share/libretro-system/bluemsx/Machines" ] ||
                return 1
            if find "$core_root/share/libretro-system/bluemsx/Machines" \
                -type f \( -iname '*.rom' -o -iname '*.bin' \) \
                ! -path '* - C-BIOS/*' -print -quit |
                grep -q .; then
                return 1
            fi
            [ -s "$core_root/licenses/bluemsx-C-BIOS-LICENSE.txt" ] ||
                return 1
            ;;
        vice_x64|vice_xvic)
            if find "$core_root/share/libretro-system/vice" -type f \
                ! \( -iname '*.vkm' -o -iname '*.vjm' -o -iname '*.vpl' \
                   -o -iname '*.sym' -o -iname '*.vrs' -o -iname '*.png' \
                   -o -iname '*.svg' -o -iname '*.ttf' -o -iname '*.xml' \
                   -o -iname '*.txt' -o -iname '*.rc' -o -iname '*.ini' \
                   -o -iname '*.json' \) \
                -print -quit | grep -q .; then
                return 1
            fi
            ;;
    esac

    expected_fingerprint="$(fingerprint_for "$id")"
    recorded_fingerprint="$(
        sed -n '1p' "$core_out/build-fingerprint" 2>/dev/null || true
    )"
    if [ "$ADOPT_EXISTING" -eq 1 ] &&
       [ "$recorded_fingerprint" != "$expected_fingerprint" ]; then
        # Explicit adoption is for already checksum-valid, source-pinned
        # artifacts after a toolchain image refresh. Never do this during the
        # default cache path.
        printf '%s\n' "$expected_fingerprint" >"$core_out/build-fingerprint"
        recorded_fingerprint="$expected_fingerprint"
    fi
    [ "$recorded_fingerprint" = "$expected_fingerprint" ]
}

ensure_core_info() {
    if [ ! -d "$CORE_INFO_ROOT/.git" ]; then
        git clone "$CORE_INFO_REPO" "$CORE_INFO_ROOT"
    fi
    if [ "$(git -C "$CORE_INFO_ROOT" rev-parse HEAD 2>/dev/null || true)" != "$CORE_INFO_REF" ]; then
        git -C "$CORE_INFO_ROOT" fetch --tags --quiet origin
        git -C "$CORE_INFO_ROOT" checkout --quiet "$CORE_INFO_REF"
        git -C "$CORE_INFO_ROOT" reset --hard --quiet
        git -C "$CORE_INFO_ROOT" clean -fdx --quiet
    fi
}

stage_scummvm_catalog_assets() {
    local status_file="$OUT_ROOT/status/scummvm"
    local source_root="$WORK_ROOT/scummvm"
    local bundle_root="$source_root/backends/platform/libretro"
    local bundle_script="$bundle_root/scripts/bundle_datafiles.sh"
    local bundle_zip="$bundle_root/scummvm.zip"
    local target_parent="$PLUMOS_DIR/share/libretro-system"
    local theme_target="$target_parent/scummvm/theme"
    local theme_relative
    local row repo ref

    [ -f "$status_file" ] &&
        [ "$(cat "$status_file")" = pass ] ||
        return 0

    row="$(recipe_row scummvm)"
    repo="$(printf '%s\n' "$row" | awk -F'|' '{ print $3 }')"
    ref="$(printf '%s\n' "$row" | awk -F'|' '{ print $4 }')"
    if [ ! -d "$source_root/.git" ]; then
        git clone "$repo" "$source_root"
        git -C "$source_root" checkout --quiet "$ref"
    fi
    [ "$(git -C "$source_root" rev-parse HEAD)" = "$ref" ] || {
        printf 'error: ScummVM asset source is not at pinned ref %s\n' \
            "$ref" >&2
        return 1
    }
    [ -x "$bundle_script" ] && command -v zip >/dev/null &&
        command -v unzip >/dev/null || {
        printf 'error: ScummVM asset packaging tools are unavailable\n' >&2
        return 1
    }

    bash "$bundle_script" \
        "$bundle_root" "$source_root" bundle scummvm
    [ -s "$bundle_zip" ] || {
        printf 'error: ScummVM datafile bundle was not created\n' >&2
        return 1
    }
    unzip -q -o "$bundle_zip" -d "$target_parent"
    mkdir -p "$theme_target"
    while IFS= read -r theme_relative; do
        [ -f "$source_root/$theme_relative" ] || {
            printf 'error: ScummVM theme asset is missing: %s\n' \
                "$theme_relative" >&2
            return 1
        }
        install -m 0644 "$source_root/$theme_relative" "$theme_target/"
    done < <(
        sed -n \
            's#^[^[:space:]]*[[:space:]]*FILE[[:space:]]*"\(gui/themes/[^"]*\)".*#\1#p' \
            "$source_root/dists/scummvm.rc"
    )
    [ -f "$target_parent/scummvm/extra/sky.cpt" ] &&
        [ -f "$target_parent/scummvm/theme/scummclassic.zip" ] || {
        printf 'error: ScummVM packaged assets are incomplete\n' >&2
        return 1
    }
}

normalize_catalog_core_info() {
    local info="$PLUMOS_DIR/info/px68k_libretro.info"
    local normalized="$info.normalized"
    local numero_info

    [ -f "$info" ] || return 0
    if ! awk '
            /^savestate = / {
                print "savestate = \"false\""
                replaced++
                next
            }
            { print }
            END {
                if (replaced != 1) {
                    exit 1
                }
            }
        ' "$info" >"$normalized"; then
        rm -f "$normalized"
        printf 'error: PX68k savestate metadata was not normalized\n' >&2
        return 1
    fi
    mv "$normalized" "$info"

    # Upstream Numero metadata omits the calculator ROMs even though the core
    # refuses to boot without any one of these three files.  Keep this as an
    # any-of requirement: ti83se.rom is preferred, not uniquely mandatory.
    numero_info="$PLUMOS_DIR/info/numero_libretro.info"
    normalized="$numero_info.normalized"
    [ -f "$numero_info" ] || return 0
    if ! awk '
            !/^firmware(_policy|_count|[0-9]+_(desc|path|opt)) = / { print }
        ' "$numero_info" >"$normalized"; then
        rm -f "$normalized"
        printf 'error: Numero firmware metadata was not normalized\n' >&2
        return 1
    fi
    cat >>"$normalized" <<'EOF'
firmware_policy = "required-any"
firmware_count = 3
firmware0_desc = "TI-83 Silver Edition ROM (recommended)"
firmware0_path = "ti83se.rom"
firmware0_opt = "true"
firmware1_desc = "TI-83 Plus ROM"
firmware1_path = "ti83plus.rom"
firmware1_opt = "true"
firmware2_desc = "TI-83 ROM"
firmware2_path = "ti83.rom"
firmware2_opt = "true"
EOF
    mv "$normalized" "$numero_info"
}

build_one() {
    local id="$1"
    local core_out="$OUT_ROOT/per-core/$id"
    local log="$OUT_ROOT/logs/$id.log"
    local fingerprint
    if validate_existing "$id"; then
        printf 'pass\n' >"$OUT_ROOT/status/$id"
        printf 'BUILD_CACHE_HIT %s\n' "$id"
        return 0
    fi
    if docker run --rm --platform linux/arm64 \
       --user "$(id -u):$(id -g)" \
       -e HOME=/tmp \
       -e JOBS="$per_core_jobs" \
       -e PLUMOS_BUBBLE_CORE_INFO_ROOT="/workspace/${CORE_INFO_ROOT#"$ROOT_DIR/"}" \
       -v "$ROOT_DIR:/workspace" -w /workspace "$TOOLCHAIN_IMAGE" \
       /workspace/scripts/build-libretro-cores-bubble.sh \
           --filter "$id" \
           --out-dir "${core_out#"$ROOT_DIR/"}" \
           --work-dir "${WORK_ROOT#"$ROOT_DIR/"}" >"$log" 2>&1; then
        fingerprint="$(fingerprint_for "$id")"
        printf '%s\n' "$fingerprint" >"$core_out/build-fingerprint"
        if validate_existing "$id" 1; then
            printf 'pass\n' >"$OUT_ROOT/status/$id"
            printf 'BUILD_PASS %s\n' "$id"
        else
            printf 'fail rc=cache-validation\n' >"$OUT_ROOT/status/$id"
            printf 'BUILD_FAIL %s rc=cache-validation log=%s\n' "$id" "$log"
        fi
    else
        rc=$?
        printf 'fail rc=%s\n' "$rc" >"$OUT_ROOT/status/$id"
        printf 'BUILD_FAIL %s rc=%s log=%s\n' "$id" "$rc" "$log"
    fi
}

printf 'catalog_build filter=%s cores=%s concurrency=%s per_core_jobs=%s\n' \
    "$FILTER" "${#ids[@]}" "$CONCURRENCY" "$per_core_jobs"

ensure_core_info
for id in "${ids[@]}"; do
    build_one "$id" &
    while [ "$(jobs -pr | wc -l | tr -d ' ')" -ge "$CONCURRENCY" ]; do
        sleep 0.2
    done
done
wait || true

PLUMOS_DIR="$OUT_ROOT/plumos"
COMPONENT_DIR="$PLUMOS_DIR/components/libretro-cores"
mkdir -p "$PLUMOS_DIR/cores" "$PLUMOS_DIR/info" \
    "$PLUMOS_DIR/emulator/lib" "$PLUMOS_DIR/share/libretro-system" \
    "$PLUMOS_DIR/licenses" "$COMPONENT_DIR"

manifest_inputs=()
pass_count=0
fail_count=0
for id in "${ids[@]}"; do
    status="$(cat "$OUT_ROOT/status/$id")"
    case "$status" in
        pass)
            core_root="$OUT_ROOT/per-core/$id/plumos"
            cp -a "$core_root/cores/." "$PLUMOS_DIR/cores/"
            cp -a "$core_root/info/." "$PLUMOS_DIR/info/"
            cp -a "$core_root/licenses/." "$PLUMOS_DIR/licenses/"
            if [ -d "$core_root/emulator/lib" ]; then
                cp -a "$core_root/emulator/lib/." \
                    "$PLUMOS_DIR/emulator/lib/"
            fi
            if [ -d "$core_root/share/libretro-system" ]; then
                cp -a "$core_root/share/libretro-system/." \
                    "$PLUMOS_DIR/share/libretro-system/"
            fi
            manifest_inputs+=(
                "$core_root/components/libretro-cores/manifest.json"
            )
            pass_count=$((pass_count + 1))
            ;;
        *)
            fail_count=$((fail_count + 1))
            ;;
    esac
done

[ "$pass_count" -gt 0 ] || {
    printf 'error: no selected core built successfully\n' >&2
    exit 1
}

normalize_catalog_core_info
stage_scummvm_catalog_assets

generated_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
source_ref="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || printf unknown)"
jq -s \
    --arg generated_at "$generated_at" \
    --arg source_ref "$source_ref" \
    --arg filter "$FILTER" \
    '{
      name:"plumOS Bubble libretro core catalog",
      component:"libretro-cores",
      device:"bubble",
      version:"1",
      architecture:"aarch64",
      rendering:"mixed",
      filter:$filter,
      source_ref:$source_ref,
      generated_at:$generated_at,
      cores:(
        map(.cores[]) |
        map(
          (
            if .id == "scummvm" then
              . + {system_asset_root:"share/libretro-system/scummvm"}
            else
              .
            end
          ) +
          {
            rendering:(
              if .id == "flycast" or
                 .id == "flycast_xtreme" or
                 .id == "km_duckswanstation_xtreme_amped" or
                 .id == "mupen64plus_next" or
                 .id == "parallel_n64" or
                 .id == "yabasanshiro"
              then "hardware-gles"
              else "software"
              end
            )
          }
        ) |
        sort_by(.id)
      )
    }' "${manifest_inputs[@]}" >"$COMPONENT_DIR/manifest.json"

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

printf 'catalog_result pass=%s fail=%s output=%s\n' \
    "$pass_count" "$fail_count" "$OUT_ROOT"
[ "$fail_count" -eq 0 ] || [ "$FAIL_ON_CORE_ERROR" -eq 0 ]
