#!/usr/bin/env bash

# Copy the non-base shared-library closure of one or more ELF files into a
# package-local directory. Loader-visible SONAMEs are regular files so the
# app-layer checksum list covers every path used at runtime.
copy_elf_runtime_deps() {
    local destination=$1
    shift
    local elf path soname real real_name

    mkdir -p "$destination"
    for elf in "$@"; do
        while IFS= read -r path; do
            [ -f "$path" ] || continue
            soname="$(basename "$path")"
            case "$soname" in
                ld-linux-*.so.*|libc.so.*|libm.so.*|libpthread.so.*|\
                libdl.so.*|librt.so.*|libEGL.so.*|libGLESv2.so.*|\
                libGL.so.*|libgbm.so.*|libmali.so.*)
                    continue
                    ;;
            esac
            real="$(readlink -f "$path")"
            real_name="$(basename "$real")"
            if [ ! -f "$destination/$real_name" ]; then
                install -m 0644 "$real" "$destination/$real_name"
                copy_elf_runtime_deps "$destination" "$real"
            fi
            if [ "$soname" != "$real_name" ] &&
                [ ! -f "$destination/$soname" ]; then
                install -m 0644 "$real" "$destination/$soname"
            fi
        done < <(
            ldd "$elf" 2>/dev/null |
                awk '/=> \/[^ ]+/ {print $3} /^[[:space:]]*\// {print $1}' |
                sort -u
        )
    done
}
