#!/usr/bin/env bash

# Shared libretro package identity used by both the per-core builder and the
# catalog cache validator. The caller must define ROOT_DIR.

bubble_libretro_package_revision() {
    case "$1" in
        beetle_saturn|dosbox_pure|\
        km_duckswanstation_xtreme_amped|km_mame2003_xtreme|\
        km_superbroswar|puae|puae2021)
            printf '%s\n' output-name-alias-v1
            ;;
        flycast_xtreme) printf '%s\n' flycast-xtreme-openmp-runtime-v3 ;;
        easyrpg) printf '%s\n' easyrpg-runtime-v1 ;;
        bluemsx) printf '%s\n' bluemsx-cbios-safe-default-v3 ;;
        vice_x64|vice_xvic) printf '%s\n' vice-no-firmware-assets-v2 ;;
        scummvm) printf '%s\n' scummvm-mf-audio-clock-v1 ;;
        parallel_n64) printf '%s\n' parallel-n64-rk3566-v1 ;;
        mupen64plus_next)
            printf '%s\n' mupen64plus-next-mali-buffer-storage-v1
            ;;
        mba_mini) printf '%s\n' mba-mini-synchronous-work-queue-v2 ;;
        vemulator) printf '%s\n' vemulator-flash-writer-init-v1 ;;
        nekop2) printf '%s\n' nekop2-np2kai-bios-fallback-v1 ;;
        retro8) printf '%s\n' retro8-pico8-audio-v1 ;;
        yabasanshiro)
            printf '%s\n' yabasanshiro-bubble-clang-arm64-vdp1-sched-other-ccd-v4
            ;;
        ecwolf) printf '%s\n' ecwolf-libretro-submodule-v1 ;;
        *) printf '%s\n' base-v1 ;;
    esac
}

bubble_libretro_patch_sha256() {
    local id="$1"
    local patch=""
    case "$id" in
        bluemsx) patch=bluemsx-cbios-safe-default.patch ;;
        scummvm) patch=scummvm-libretro-audio-clock.patch ;;
        parallel_n64) patch=parallel-n64-rk3566.patch ;;
        mupen64plus_next)
            patch=mupen64plus-next-mali-buffer-storage.patch
            ;;
        mba_mini)
            {
                sha256sum \
                    "$ROOT_DIR/patches/libretro-cores-bubble/mba-mini-osd-debugger-stub.patch" |
                    awk '{ print $1 }'
                sha256sum \
                    "$ROOT_DIR/patches/libretro-cores-bubble/mba-mini-synchronous-work-queue.patch" |
                    awk '{ print $1 }'
            } | sha256sum | awk '{ print $1 }'
            return
            ;;
        vemulator) patch=vemulator-flash-writer-init.patch ;;
        nekop2) patch=nekop2-np2kai-bios-fallback.patch ;;
        retro8) patch=retro8-pico8-audio.patch ;;
        yabasanshiro)
            {
                sha256sum \
                    "$ROOT_DIR/patches/libretro-cores-bubble/yabasanshiro-2.10.4-arm64-gcc12.patch" |
                    awk '{ print $1 }'
                sha256sum \
                    "$ROOT_DIR/patches/libretro-cores-bubble/yabasanshiro-2.10.4-vdp1-framebuffer-readback.patch" |
                    awk '{ print $1 }'
                sha256sum \
                    "$ROOT_DIR/patches/libretro-cores-bubble/yabasanshiro-2.10.4-libretro-ccd-file-size.patch" |
                    awk '{ print $1 }'
                sha256sum \
                    "$ROOT_DIR/patches/libretro-cores-bubble/yabasanshiro-2.10.4-bubble-sched-other.patch" |
                    awk '{ print $1 }'
            } | sha256sum | awk '{ print $1 }'
            return
            ;;
    esac
    if [ -n "$patch" ]; then
        sha256sum "$ROOT_DIR/patches/libretro-cores-bubble/$patch" |
            awk '{ print $1 }'
    else
        printf '%s\n' none
    fi
}
