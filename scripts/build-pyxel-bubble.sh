#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"
TARGET_DIR="${TARGET_DIR:-$ROOT_DIR/output/pyxel/bubble}"
LOCK_FILE="${PLUMOS_BUBBLE_PYXEL_LOCK:-$ROOT_DIR/package/pyxel-bubble/requirements.lock.txt}"
DEFAULT_REQUIREMENTS="${PLUMOS_BUBBLE_PYXEL_REQUIREMENTS:-$ROOT_DIR/package/pyxel-bubble/requirements.txt}"
FIT_SOURCE="$ROOT_DIR/package/pyxel-bubble/plumos_pyxel_fit.c"
PYTHON_VERSION="${PLUMOS_BUBBLE_PYTHON_VERSION:-3.11}"
PYTHON_BIN="${PLUMOS_BUBBLE_PYTHON_BIN:-/usr/bin/python3.11}"
PIP_VERSION="${PLUMOS_BUBBLE_PIP_VERSION:-23.0.1}"
PIP_CACHE_DIR="${PLUMOS_BUBBLE_PIP_CACHE:-$ROOT_DIR/build/pip-cache}"
SDL_VERSION="${PLUMOS_BUBBLE_PYXEL_SDL_VERSION:-2.32.0}"
SDL_SHA256="${PLUMOS_BUBBLE_PYXEL_SDL_SHA256:-f5c2b52498785858f3de1e2996eba3c1b805d08fe168a47ea527c7fc339072d0}"
SDL_ARCHIVE="$ROOT_DIR/build/downloads/SDL2-$SDL_VERSION.tar.gz"
SDL_BUILD_ROOT="$ROOT_DIR/build/pyxel-bubble-sdl2"
READELF="${READELF:-readelf}"
STRIP="${STRIP:-strip}"
CC="${CC:-gcc}"
source_ref="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || printf unknown)"
source_epoch="${SOURCE_DATE_EPOCH:-}"
[ -n "$source_epoch" ] || source_epoch="$(git -C "$ROOT_DIR" show -s --format=%ct HEAD 2>/dev/null || date +%s)"

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

find_target_lib() {
    local name="$1"
    local dir bundled
    if [ -n "${TARGET_DIR:-}" ] && [ -d "$TARGET_DIR" ]; then
        bundled="$(find "$TARGET_DIR" -type f -name "$name" -print -quit)"
        if [ -n "$bundled" ]; then
            printf '%s\n' "$bundled"
            return 0
        fi
    fi
    for dir in /lib/aarch64-linux-gnu /usr/lib/aarch64-linux-gnu /lib /usr/lib; do
        if [ -e "$dir/$name" ]; then
            readlink -f "$dir/$name"
            return 0
        fi
    done
    return 1
}

copy_dependency_tree() {
    local elf="$1"
    local destination="$2"
    local dependency source
    "$READELF" -d "$elf" 2>/dev/null |
        awk -F'[][]' '/NEEDED/ { print $2 }' |
        while IFS= read -r dependency; do
            [ "$dependency" = "ld-linux-aarch64.so.1" ] && continue
            [ -e "$destination/$dependency" ] && continue
            source="$(find_target_lib "$dependency" || true)"
            [ -n "$source" ] || fail "runtime dependency not found: $dependency"
            install -m 0644 "$source" "$destination/$dependency"
            copy_dependency_tree "$source" "$destination"
        done
}

materialize_links() {
    local root="$1"
    local link target
    while IFS= read -r link; do
        target="$(readlink -f "$link")"
        [ -f "$target" ] || fail "unsupported Python symlink: $link"
        rm -f "$link"
        cp -p "$target" "$link"
    done < <(find "$root" -type l -print)
}

fetch_sdl() {
    local url="https://github.com/libsdl-org/SDL/releases/download/release-$SDL_VERSION/SDL2-$SDL_VERSION.tar.gz"
    mkdir -p "$(dirname "$SDL_ARCHIVE")"
    if [ ! -r "$SDL_ARCHIVE" ] ||
        ! printf '%s  %s\n' "$SDL_SHA256" "$SDL_ARCHIVE" | sha256sum -c - >/dev/null 2>&1; then
        curl -LfsS "$url" -o "$SDL_ARCHIVE"
    fi
    printf '%s  %s\n' "$SDL_SHA256" "$SDL_ARCHIVE" | sha256sum -c -
}

build_sdl() {
    local jobs
    jobs="$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '4')"
    rm -rf "$SDL_BUILD_ROOT"
    mkdir -p "$SDL_BUILD_ROOT/source" "$SDL_BUILD_ROOT/build" "$SDL_BUILD_ROOT/stage"
    tar -C "$SDL_BUILD_ROOT/source" --strip-components=1 -xf "$SDL_ARCHIVE"
    (
        cd "$SDL_BUILD_ROOT/build"
        "$SDL_BUILD_ROOT/source/configure" \
            --prefix=/usr \
            --disable-video-x11 \
            --disable-video-wayland \
            --disable-video-opengl \
            --enable-video-opengles \
            --enable-video-kmsdrm \
            --enable-alsa \
            --disable-pulseaudio \
            --disable-jack \
            --disable-sndio \
            --disable-static
        make -j"$jobs"
        make DESTDIR="$SDL_BUILD_ROOT/stage" install
    )
}

[ -x "$PYTHON_BIN" ] || fail "Python runtime is missing: $PYTHON_BIN"
"$PYTHON_BIN" -m pip --version >/dev/null 2>&1 ||
    fail "python3-pip is required in the Bubble toolchain image"
[ -r "$LOCK_FILE" ] || fail "Pyxel lock file is missing: $LOCK_FILE"
[ -r "$DEFAULT_REQUIREMENTS" ] ||
    fail "Pyxel default requirements are missing: $DEFAULT_REQUIREMENTS"
[ -r "$FIT_SOURCE" ] ||
    fail "Pyxel display fit source is missing: $FIT_SOURCE"
fetch_sdl
build_sdl

rm -rf "$TARGET_DIR"
PYTHON_ROOT="$TARGET_DIR/plumos/apps/python"
PYXEL_ROOT="$TARGET_DIR/plumos/apps/pyxel"
PYTHON_SITE="$PYTHON_ROOT/site-packages"
PYXEL_SITE="$PYXEL_ROOT/site"
PYXEL_LIB="$PYXEL_ROOT/lib"
mkdir -p \
    "$PYTHON_ROOT/bin" "$PYTHON_ROOT/lib" "$PYTHON_SITE" \
    "$PYXEL_SITE" "$PYXEL_LIB" \
    "$TARGET_DIR/plumos/bin" \
    "$TARGET_DIR/plumos/components/pyxel" \
    "$TARGET_DIR/plumos/share/pyxel" \
    "$TARGET_DIR/plumos/share/doc/pyxel"

install -m 0755 "$PYTHON_BIN" "$PYTHON_ROOT/bin/python3.11"
cp -a "/usr/lib/python${PYTHON_VERSION}" "$PYTHON_ROOT/lib/"
rm -rf \
    "$PYTHON_ROOT/lib/python${PYTHON_VERSION}/config-"* \
    "$PYTHON_ROOT/lib/python${PYTHON_VERSION}/idlelib" \
    "$PYTHON_ROOT/lib/python${PYTHON_VERSION}/test" \
    "$PYTHON_ROOT/lib/python${PYTHON_VERSION}/tkinter" \
    "$PYTHON_ROOT/lib/python${PYTHON_VERSION}/turtledemo"
find "$PYTHON_ROOT" -type d -name __pycache__ -prune -exec rm -rf {} +
materialize_links "$PYTHON_ROOT"

mkdir -p "$PIP_CACHE_DIR"
PIP_CACHE_DIR="$PIP_CACHE_DIR" PIP_DISABLE_PIP_VERSION_CHECK=1 "$PYTHON_BIN" -m pip install \
    --break-system-packages \
    --no-compile \
    --only-binary=:all: \
    --target "$PYTHON_SITE" \
    "pip==$PIP_VERSION"
PIP_CACHE_DIR="$PIP_CACHE_DIR" PIP_DISABLE_PIP_VERSION_CHECK=1 "$PYTHON_BIN" -m pip install \
    --break-system-packages \
    --no-compile \
    --only-binary=:all: \
    --requirement "$LOCK_FILE" \
    --target "$PYXEL_SITE"

find "$PYXEL_SITE" -type d \( -name test -o -name tests \) -prune \
    -exec rm -rf {} +
rm -rf \
    "$PYXEL_SITE/pygame/docs" \
    "$PYXEL_SITE/pygame/examples" \
    "$PYXEL_SITE/pyxel/examples"
find "$PYXEL_SITE" -type d -name __pycache__ -prune -exec rm -rf {} +

install -m 0644 "$DEFAULT_REQUIREMENTS" \
    "$TARGET_DIR/plumos/share/pyxel/requirements.txt"
install -m 0644 "$LOCK_FILE" \
    "$TARGET_DIR/plumos/share/pyxel/requirements.lock.txt"
install -m 0644 /etc/ssl/certs/ca-certificates.crt \
    "$PYTHON_ROOT/ca-certificates.crt"

loader="$(find_target_lib ld-linux-aarch64.so.1)" ||
    fail "AArch64 loader not found"
install -m 0755 "$loader" "$PYTHON_ROOT/lib/ld-linux-aarch64.so.1"
copy_dependency_tree "$PYTHON_ROOT/bin/python3.11" "$PYTHON_ROOT/lib"

while IFS= read -r elf; do
    copy_dependency_tree "$elf" "$PYTHON_ROOT/lib"
done < <(
    find "$PYTHON_ROOT/lib/python${PYTHON_VERSION}" -type f \
        -exec sh -c '
            for path do
                case "$(file -b "$path" 2>/dev/null)" in
                    ELF*) printf "%s\n" "$path" ;;
                esac
            done
        ' sh {} +
)

custom_sdl="$(find "$SDL_BUILD_ROOT/stage/usr/lib" -type f \
    -name 'libSDL2-2.0.so.*' -print | sort | tail -n 1)"
[ -n "$custom_sdl" ] || fail "custom SDL2 library was not produced"
install -m 0644 "$custom_sdl" "$PYXEL_LIB/libSDL2-2.0.so.0"
"$STRIP" --strip-unneeded "$PYXEL_LIB/libSDL2-2.0.so.0"
copy_dependency_tree "$custom_sdl" "$PYXEL_LIB"
for library in libgbm.so.1; do
    [ ! -e "$PYXEL_LIB/$library" ] || continue
    source="$(find_target_lib "$library" || true)"
    [ -n "$source" ] || fail "Pyxel display library is missing: $library"
    install -m 0644 "$source" "$PYXEL_LIB/$library"
    copy_dependency_tree "$source" "$PYXEL_LIB"
done
# Pyxel's manylinux binding still declares the pre-glibc-2.34 libdl
# compatibility DSO. Bubble's minimal System intentionally does not provide
# that stub, so keep it component-scoped beside the binding.
compat_path="$(find_target_lib libdl.so.2 || true)"
[ -n "$compat_path" ] || fail "Pyxel glibc compatibility library is missing: libdl.so.2"
install -m 0644 "$compat_path" "$PYXEL_LIB/libdl.so.2"
"$CC" -O2 -fPIC -Wall -Wextra -Werror -shared \
    -Wl,-soname,plumos-pyxel-fit.so \
    -o "$PYXEL_LIB/plumos-pyxel-fit.so" "$FIT_SOURCE" -ldl
"$STRIP" --strip-unneeded "$PYXEL_LIB/plumos-pyxel-fit.so"

cat >"$TARGET_DIR/plumos/bin/plumos-python-bubble" <<'EOF'
#!/bin/sh
set -eu

PLUMOS_ROOT="${PLUMOS_ROOT:-/storage/plumos}"
PYTHON_ROOT="${PLUMOS_BUBBLE_PYTHON_ROOT:-$PLUMOS_ROOT/apps/python}"
PYXEL_ROOT="${PLUMOS_BUBBLE_PYXEL_ROOT:-$PLUMOS_ROOT/apps/pyxel}"
PYTHON="$PYTHON_ROOT/bin/python3.11"
LOADER="$PYTHON_ROOT/lib/ld-linux-aarch64.so.1"

[ -x "$PYTHON" ] || {
  printf 'error: Bubble Python runtime is missing: %s\n' "$PYTHON" >&2
  exit 127
}
[ -x "$LOADER" ] || {
  printf 'error: Bubble Python loader is missing: %s\n' "$LOADER" >&2
  exit 127
}

export PYTHONHOME="$PYTHON_ROOT"
export PYTHONNOUSERSITE=1
export PYTHONDONTWRITEBYTECODE=1
export PYTHONPATH="$PYTHON_ROOT/site-packages${PLUMOS_PYTHON_EXTRA_PATH:+:$PLUMOS_PYTHON_EXTRA_PATH}"
export SSL_CERT_FILE="${SSL_CERT_FILE:-$PYTHON_ROOT/ca-certificates.crt}"
export REQUESTS_CA_BUNDLE="${REQUESTS_CA_BUNDLE:-$SSL_CERT_FILE}"
# Keep the Python utility route (Pyxel Setup and PortMaster Update) on the
# same component-scoped C++ runtime as the validated Pyxel game launcher.
# The Bubble base System intentionally does not provide libgcc_s/libstdc++.
PYTHON_LIBRARY_PATH="$PYXEL_ROOT/lib:$PYTHON_ROOT/lib:$PLUMOS_ROOT/emulator/lib:/usr/lib"
if [ -n "${PLUMOS_BUBBLE_PYTHON_EXTRA_LIBRARY_PATH:-}" ]; then
  PYTHON_LIBRARY_PATH="${PLUMOS_BUBBLE_PYTHON_EXTRA_LIBRARY_PATH}:$PYTHON_LIBRARY_PATH"
fi
# The stock BusyBox shell and the bundled Python runtime use different libc
# environments. Defer preload activation until this shell execs Python's
# explicit glibc loader; exporting it in the outer launcher crashes BusyBox.
if [ -n "${PLUMOS_BUBBLE_PYTHON_LD_PRELOAD:-}" ]; then
  export LD_PRELOAD="$PLUMOS_BUBBLE_PYTHON_LD_PRELOAD"
fi
exec "$LOADER" \
  --library-path "$PYTHON_LIBRARY_PATH" \
  --argv0 "$PLUMOS_ROOT/bin/python3" \
  "$PYTHON" "$@"
EOF

cat >"$TARGET_DIR/plumos/bin/plumos-pyxel-bubble-launch" <<'EOF'
#!/bin/sh
set -eu

if [ "${PLUMOS_PYXEL_BUSYBOX_REEXEC:-0}" != 1 ]; then
    early_busybox="${PLUMOS_BUSYBOX:-/bin/busybox}"
    if [ -x "$early_busybox" ]; then
        export PLUMOS_PYXEL_BUSYBOX_REEXEC=1
        exec "$early_busybox" sh "$0" "$@"
    fi
fi

PLUMOS_ROOT="${PLUMOS_ROOT:-/storage/plumos}"
BB="${PLUMOS_BUSYBOX:-/bin/busybox}"
PYTHON_ROOT="${PLUMOS_BUBBLE_PYTHON_ROOT:-$PLUMOS_ROOT/apps/python}"
PYXEL_ROOT="${PLUMOS_BUBBLE_PYXEL_ROOT:-$PLUMOS_ROOT/apps/pyxel}"
USER_SITE="${PLUMOS_PYXEL_USER_SITE:-$PLUMOS_ROOT/state/pyxel-site}"
BASE_SITE="$PYXEL_ROOT/site"
FIT_LIBRARY="${PLUMOS_PYXEL_FIT_LIBRARY:-$PYXEL_ROOT/lib/plumos-pyxel-fit.so}"
MALI_LIBRARY="${PLUMOS_PYXEL_MALI_LIBRARY:-$PLUMOS_ROOT/emulator/lib/libmali.so.1}"
LOG_DIR="${PLUMOS_PYXEL_LOG_DIR:-$PLUMOS_ROOT/logs/pyxel}"
RUNTIME_ROOT="${PLUMOS_RUNTIME_ROOT:-/run/plumos}"
CPU_CONTROL="$PLUMOS_ROOT/bin/plumos-cpu-control"
CPU_POLICY="${PLUMOS_PYXEL_CPU_POLICY:-performance}"
CPU_SNAPSHOT="$RUNTIME_ROOT/pyxel/cpu-governors.$$"
CPU_SNAPSHOT_ACTIVE=0
PYXEL_PID=""
[ -x "$BB" ] || BB=/bin/busybox
mkdir -p "$LOG_DIR" "$RUNTIME_ROOT/pyxel" 2>/dev/null || true

restore_cpu_policy() {
  if [ "$CPU_SNAPSHOT_ACTIVE" -eq 1 ]; then
    "$BB" sh "$CPU_CONTROL" restore "$CPU_SNAPSHOT" >/dev/null 2>&1 || true
    CPU_SNAPSHOT_ACTIVE=0
  fi
}

cleanup_pyxel() {
  signal_rc="${1:-0}"
  if [ -n "$PYXEL_PID" ] && kill -0 "$PYXEL_PID" 2>/dev/null; then
    kill -TERM "$PYXEL_PID" 2>/dev/null || true
    count=0
    while kill -0 "$PYXEL_PID" 2>/dev/null && [ "$count" -lt 50 ]; do
      "$BB" usleep 100000
      count=$((count + 1))
    done
    kill -0 "$PYXEL_PID" 2>/dev/null && kill -KILL "$PYXEL_PID" 2>/dev/null || true
    wait "$PYXEL_PID" 2>/dev/null || true
  fi
  PYXEL_PID=""
  restore_cpu_policy
  trap - EXIT HUP INT TERM
  [ "$signal_rc" -eq 0 ] || exit "$signal_rc"
}

trap 'cleanup_pyxel 0' EXIT
trap 'cleanup_pyxel 129' HUP
trap 'cleanup_pyxel 130' INT
trap 'cleanup_pyxel 143' TERM

AUDIO_OUTPUT="$PLUMOS_ROOT/bin/plumos-audio-output"
if [ -x "$AUDIO_OUTPUT" ]; then
  "$BB" sh "$AUDIO_OUTPUT" prepare >>"$LOG_DIR/audio.log" 2>&1 || {
    printf 'stage=P61_AUDIO result=failed router=managed\n' >>"$LOG_DIR/runtime.log"
    printf 'plumos-pyxel-bubble-launch: audio route preparation failed\n' >&2
    exit 1
  }
  export ALSA_CONFIG_PATH="${ALSA_CONFIG_PATH:-/run/plumos/audio/asound.conf}"
  export AUDIODEV="${AUDIODEV:-plumos_pyxel}"
else
  export ALSA_CONFIG_PATH="${ALSA_CONFIG_PATH:-$PLUMOS_ROOT/share/alsa/alsa.conf}"
  export AUDIODEV="${AUDIODEV:-default}"
fi
if [ -x "$PLUMOS_ROOT/bin/plumos-volume-control" ]; then
  "$BB" sh "$PLUMOS_ROOT/bin/plumos-volume-control" apply \
    >>"$LOG_DIR/audio.log" 2>&1 || true
fi

export HOME="${PLUMOS_PYXEL_HOME:-$PLUMOS_ROOT/state/pyxel-home}"
mkdir -p "$HOME" 2>/dev/null || true
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$PLUMOS_ROOT/cache/mesa}"
mkdir -p "$XDG_CACHE_HOME" 2>/dev/null || true
export PLUMOS_PYTHON_EXTRA_PATH="$USER_SITE:$BASE_SITE"
export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-kmsdrm}"
export SDL_RENDER_DRIVER="${SDL_RENDER_DRIVER:-opengles2}"
export SDL_AUDIODRIVER="${SDL_AUDIODRIVER:-alsa}"
[ ! -d "$PLUMOS_ROOT/lib/alsa-lib" ] ||
  export ALSA_PLUGIN_DIR="${ALSA_PLUGIN_DIR:-$PLUMOS_ROOT/lib/alsa-lib}"
export SDL_VIDEO_KMSDRM_DEVICE_INDEX="${SDL_VIDEO_KMSDRM_DEVICE_INDEX:-0}"
[ -c /dev/mali0 ] && [ -r "$MALI_LIBRARY" ] || {
  printf 'stage=P62_VIDEO result=failed renderer=mali-g52 reason=hardware-runtime-missing\n' >>"$LOG_DIR/runtime.log"
  printf 'plumos-pyxel-bubble-launch: Bubble Mali hardware runtime is unavailable\n' >&2
  exit 1
}
# RK3566's stock driver is one stateful mega-DSO. Loading copied EGL and GLES
# aliases as different files creates two driver states. Use the exact same DSO
# for EGL, GLES and the fit adapter, and never fall back to Mesa software GL.
export PLUMOS_BUBBLE_PYTHON_EXTRA_LIBRARY_PATH="$PLUMOS_ROOT/emulator/lib${PLUMOS_BUBBLE_PYTHON_EXTRA_LIBRARY_PATH:+:$PLUMOS_BUBBLE_PYTHON_EXTRA_LIBRARY_PATH}"
export SDL_VIDEO_EGL_DRIVER="${SDL_VIDEO_EGL_DRIVER:-$MALI_LIBRARY}"
export SDL_VIDEO_GL_DRIVER="${SDL_VIDEO_GL_DRIVER:-$MALI_LIBRARY}"
export PLUMOS_PYXEL_GLES_LIBRARY="${PLUMOS_PYXEL_GLES_LIBRARY:-$MALI_LIBRARY}"
unset LIBGL_ALWAYS_SOFTWARE MESA_LOADER_DRIVER_OVERRIDE \
  LIBGL_DRIVERS_PATH __EGL_VENDOR_LIBRARY_FILENAMES
export SDL_GAMECONTROLLERCONFIG="${SDL_GAMECONTROLLERCONFIG:-190000004b4800000111000000010000,retrogame_joypad,a:b1,b:b0,x:b2,y:b3,leftshoulder:b4,rightshoulder:b5,lefttrigger:b6,righttrigger:b7,back:b8,start:b9,guide:b17,leftstick:b11,rightstick:b12,dpup:b13,dpdown:b14,dpleft:b15,dpright:b16,leftx:a0,lefty:a1,rightx:a3,righty:a4,platform:Linux,}"
if [ -r "$FIT_LIBRARY" ] && [ "${PLUMOS_PYXEL_FIT:-1}" != "0" ]; then
  export PLUMOS_PYXEL_FIT=1
  export PLUMOS_PYXEL_FIT_WIDTH="${PLUMOS_PYXEL_FIT_WIDTH:-640}"
  export PLUMOS_PYXEL_FIT_HEIGHT="${PLUMOS_PYXEL_FIT_HEIGHT:-480}"
  export PLUMOS_BUBBLE_PYTHON_LD_PRELOAD="$FIT_LIBRARY${PLUMOS_BUBBLE_PYTHON_LD_PRELOAD:+:$PLUMOS_BUBBLE_PYTHON_LD_PRELOAD}"
fi

case "$CPU_POLICY" in
  interactive|performance|ondemand|schedutil|conservative) ;;
  *)
    printf 'plumos-pyxel-bubble-launch: invalid CPU policy: %s\n' "$CPU_POLICY" >&2
    exit 2
    ;;
esac
if [ -x "$CPU_CONTROL" ] &&
   "$BB" sh "$CPU_CONTROL" snapshot "$CPU_SNAPSHOT"; then
  CPU_SNAPSHOT_ACTIVE=1
  if "$BB" sh "$CPU_CONTROL" apply "$CPU_POLICY"; then
    printf 'stage=P63_CPU result=ok requested=%s active=%s\n' "$CPU_POLICY" \
      "$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null || printf unknown)" \
      >>"$LOG_DIR/runtime.log"
  else
    printf 'stage=P63_CPU result=failed requested=%s\n' "$CPU_POLICY" \
      >>"$LOG_DIR/runtime.log"
    restore_cpu_policy
    exit 1
  fi
else
  printf 'stage=P63_CPU result=failed reason=control-unavailable\n' \
    >>"$LOG_DIR/runtime.log"
  exit 1
fi

set +e
"$BB" sh "$PLUMOS_ROOT/bin/plumos-python-bubble" "$@" >>"$LOG_DIR/runtime.log" 2>&1 &
PYXEL_PID=$!
wait "$PYXEL_PID"
rc=$?
PYXEL_PID=""
set -e
restore_cpu_policy
trap - EXIT HUP INT TERM
exit "$rc"
EOF

cat >"$TARGET_DIR/plumos/bin/plumos-pyxel-setup" <<'EOF'
#!/bin/sh
set -u

PLUMOS_ROOT="${PLUMOS_ROOT:-/storage/plumos}"
PLUMOS_SDCARD_ROOT="${PLUMOS_SDCARD_ROOT:-/storage}"
ROM_DIR="${PLUMOS_PYXEL_ROM_DIR:-$PLUMOS_SDCARD_ROOT/Roms/pyxel}"
PROJECT_REQUIREMENTS="$ROM_DIR/requirements.txt"
DEFAULT_REQUIREMENTS="${PLUMOS_PYXEL_DEFAULT_REQUIREMENTS:-$PLUMOS_ROOT/share/pyxel/requirements.txt}"
USER_SITE="${PLUMOS_PYXEL_USER_SITE:-$PLUMOS_ROOT/state/pyxel-site}"
STAGING="${USER_SITE}.installing"
PREVIOUS="${USER_SITE}.previous"
LOCK_DIR="${PLUMOS_PYXEL_SETUP_LOCK:-/run/plumos/pyxel-setup.lock}"
PIP_CACHE="${PLUMOS_PYXEL_PIP_CACHE:-$PLUMOS_ROOT/cache/pip}"
TIMEOUT="${PLUMOS_PYXEL_INSTALL_TIMEOUT:-900}"
PYTHON="$PLUMOS_ROOT/bin/plumos-python-bubble"
BASE_SITE="$PLUMOS_ROOT/apps/pyxel/site"

if [ -r "$PROJECT_REQUIREMENTS" ]; then
  REQUIREMENTS="$PROJECT_REQUIREMENTS"
  REQUIREMENTS_SOURCE=project
else
  REQUIREMENTS="$DEFAULT_REQUIREMENTS"
  REQUIREMENTS_SOURCE=plumos-default
fi

log() { printf '%s\n' "$*"; }
fail() { log "ERROR: $*"; exit 1; }
release_lock() { rm -rf "$LOCK_DIR" 2>/dev/null || true; }

verify_site() {
  PLUMOS_PYTHON_EXTRA_PATH="$1:$BASE_SITE" "$PYTHON" - <<'PY'
from importlib import import_module, metadata
for distribution, module in (
    ("pyxel", "pyxel"),
    ("pygame", "pygame"),
    ("numpy", "numpy"),
    ("Pillow", "PIL"),
):
    import_module(module)
    print(f"verified {distribution}={metadata.version(distribution)}")
PY
}

print_status() {
  log "Pyxel Setup status"
  log "requirements=$REQUIREMENTS"
  log "requirements_source=$REQUIREMENTS_SOURCE"
  log "site=$USER_SITE"
  [ -x "$PYTHON" ] || fail "Bubble Python runtime is missing"
  if [ -d "$USER_SITE" ]; then
    verify_site "$USER_SITE"
  else
    log "site=using packaged baseline"
    verify_site "$BASE_SITE"
  fi
}

install_site() {
  case "$TIMEOUT" in ''|*[!0-9]*) fail "invalid timeout: $TIMEOUT" ;; esac
  [ -x "$PYTHON" ] || fail "Bubble Python runtime is missing"
  [ -r "$REQUIREMENTS" ] || fail "requirements.txt not found: $REQUIREMENTS"
  mkdir -p "$(dirname "$LOCK_DIR")" "$(dirname "$USER_SITE")" "$PIP_CACHE" ||
    fail "cannot create Pyxel setup directories"
  mkdir "$LOCK_DIR" 2>/dev/null ||
    fail "another Pyxel setup is already running"
  trap 'release_lock' EXIT
  trap 'release_lock; exit 130' HUP INT TERM

  rm -rf "$STAGING" "$PREVIOUS" ||
    fail "cannot remove stale Pyxel setup state"
  mkdir -p "$STAGING" || fail "cannot create staging site"
  log "Pyxel Setup"
  log "requirements=$REQUIREMENTS"
  log "requirements_source=$REQUIREMENTS_SOURCE"
  log "requirements_sha256=$(sha256sum "$REQUIREMENTS" | awk '{print $1}')"
  export PIP_CACHE_DIR="$PIP_CACHE"
  export PIP_DISABLE_PIP_VERSION_CHECK=1
  export PIP_NO_INPUT=1
  if command -v timeout >/dev/null 2>&1; then
    timeout "$TIMEOUT" "$PYTHON" -m pip install \
      --progress-bar off --only-binary=:all: --target "$STAGING" \
      --requirement "$REQUIREMENTS"
  else
    "$PYTHON" -m pip install \
      --progress-bar off --only-binary=:all: --target "$STAGING" \
      --requirement "$REQUIREMENTS"
  fi
  rc=$?
  [ "$rc" -eq 0 ] || {
    rm -rf "$STAGING"
    [ "$rc" -eq 124 ] && fail "pip timed out after ${TIMEOUT}s"
    fail "pip install failed rc=$rc"
  }
  verify_site "$STAGING" || {
    rm -rf "$STAGING"
    fail "module import verification failed"
  }
  [ ! -d "$USER_SITE" ] || mv "$USER_SITE" "$PREVIOUS" ||
    fail "cannot preserve current Pyxel site"
  if ! mv "$STAGING" "$USER_SITE"; then
    [ ! -d "$PREVIOUS" ] || mv "$PREVIOUS" "$USER_SITE" 2>/dev/null || true
    fail "cannot activate the new Pyxel site"
  fi
  rm -rf "$PREVIOUS"
  log "RESULT: Pyxel environment installed successfully"
}

case "${1:-install}" in
  install) install_site ;;
  status) print_status ;;
  *) log "usage: plumos-pyxel-setup [install|status]"; exit 2 ;;
esac
EOF
chmod 0755 \
    "$TARGET_DIR/plumos/bin/plumos-python-bubble" \
    "$TARGET_DIR/plumos/bin/plumos-pyxel-bubble-launch" \
    "$TARGET_DIR/plumos/bin/plumos-pyxel-setup"

PYTHONHOME="$PYTHON_ROOT" \
PYTHONPATH="$PYTHON_ROOT/site-packages:$PYXEL_SITE" \
LD_LIBRARY_PATH="$PYXEL_LIB:$PYTHON_ROOT/lib" \
PYTHONDONTWRITEBYTECODE=1 \
"$PYTHON_ROOT/bin/python3.11" - <<'PY'
from importlib import import_module, metadata
for distribution, module in (
    ("pyxel", "pyxel"),
    ("pygame", "pygame"),
    ("numpy", "numpy"),
    ("Pillow", "PIL"),
):
    import_module(module)
    print(f"{distribution}={metadata.version(distribution)}")
PY
test -f "$PYXEL_LIB/libdl.so.2"
find "$PYTHON_ROOT" "$PYXEL_ROOT" -type d -name __pycache__ -prune \
    -exec rm -rf {} +

generated_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
lock_sha256="$(sha256sum "$LOCK_FILE" | awk '{print $1}')"
cat >"$TARGET_DIR/plumos/components/pyxel/manifest.json" <<EOF
{
  "name": "plumOS Pyxel runtime for Bubble",
  "component": "pyxel",
  "device": "bubble",
  "source_ref": "$source_ref",
  "source_date_epoch": $source_epoch,
  "architecture": "aarch64",
  "python": "$PYTHON_VERSION",
  "pip": "$PIP_VERSION",
  "sdl2": "$SDL_VERSION",
  "requirements_sha256": "$lock_sha256",
  "generated_at": "$generated_at",
  "display": "SDL2 KMSDRM with Bubble Mali-G52 GLES2 and aspect-fit",
  "hardware_required": true,
  "software_fallback": false,
  "external_gpu_runtime": ["emulator/lib/libmali.so.1", "/dev/mali0"],
  "cpu_backend": "bin/plumos-cpu-control",
  "default_cpu_policy": "performance",
  "audio": "SDL2 ALSA direct-hw or managed router",
  "input": "retrogame_joypad"
}
EOF
cat >"$TARGET_DIR/plumos/share/doc/pyxel/README.txt" <<EOF
plumOS Pyxel runtime for Bubble
python=$PYTHON_VERSION
pip=$PIP_VERSION
sdl2=$SDL_VERSION
requirements_sha256=$lock_sha256
baseline=$PYXEL_SITE
user_site=/storage/plumos/state/pyxel-site
display=SDL2 KMSDRM Bubble Mali-G52 GLES2 aspect-fit
software_fallback=false
default_cpu_policy=performance
audio=ALSA direct-hw or managed router
EOF
(
    cd "$TARGET_DIR/plumos"
    find apps/python apps/pyxel \
        bin/plumos-python-bubble \
        bin/plumos-pyxel-bubble-launch \
        bin/plumos-pyxel-setup \
        share/pyxel \
        share/doc/pyxel \
        components/pyxel/manifest.json \
        -type f -print | sort |
        while IFS= read -r path; do sha256sum "$path"; done
) >"$TARGET_DIR/plumos/components/pyxel/checksums.sha256"
(
    cd "$TARGET_DIR/plumos"
    sha256sum -c components/pyxel/checksums.sha256
)
printf 'created: %s\n' "$TARGET_DIR"
