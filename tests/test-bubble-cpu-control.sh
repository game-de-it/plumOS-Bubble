#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d /tmp/plumos-bubble-cpu-test.XXXXXX)"
CPUFREQ_ROOT="$TEST_ROOT/sys/devices/system/cpu/cpufreq"
THERMAL_ROOT="$TEST_ROOT/sys/class/thermal"
RUNTIME_ROOT="$TEST_ROOT/run/plumos"
CPU_CONTROL="$ROOT_DIR/package/frontend-bubble/plumos/bin/plumos-cpu-control"

cleanup() {
  case "$TEST_ROOT" in
    /tmp/plumos-bubble-cpu-test.*)
      find "$TEST_ROOT" -type f -delete 2>/dev/null || true
      find "$TEST_ROOT" -depth -type d -exec rmdir {} \; 2>/dev/null || true
      ;;
  esac
}
trap cleanup EXIT HUP INT TERM

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_equal() { [ "$1" = "$2" ] || fail "$3: expected '$1', got '$2'"; }

for number in 0 4; do
  policy="$CPUFREQ_ROOT/policy$number"
  mkdir -p "$policy"
  printf '0 1 2 3\n' >"$policy/affected_cpus"
  printf '408000\n' >"$policy/scaling_min_freq"
  printf '1992000\n' >"$policy/scaling_max_freq"
  printf '816000\n' >"$policy/scaling_cur_freq"
  printf '408000 816000 1992000\n' >"$policy/scaling_available_frequencies"
  printf 'interactive ondemand performance schedutil conservative\n' \
    >"$policy/scaling_available_governors"
  printf 'ondemand\n' >"$policy/scaling_governor"
done

mkdir -p "$THERMAL_ROOT/thermal_zone0"
printf 'soc-thermal\n' >"$THERMAL_ROOT/thermal_zone0/type"
printf '60555\n' >"$THERMAL_ROOT/thermal_zone0/temp"
printf 'power_allocator\n' >"$THERMAL_ROOT/thermal_zone0/policy"

cpu_env() {
  PLUMOS_CPUFREQ_ROOT="$CPUFREQ_ROOT" \
  PLUMOS_THERMAL_ROOT="$THERMAL_ROOT" \
  PLUMOS_RUNTIME_ROOT="$RUNTIME_ROOT" \
    "$CPU_CONTROL" "$@"
}

status="$(cpu_env status)"
printf '%s\n' "$status" | grep -q \
  '^policy=policy0 cpus=0 1 2 3 governor=ondemand current_khz=816000' ||
  fail 'policy status'
printf '%s\n' "$status" | grep -q \
  '^thermal=thermal_zone0 type=soc-thermal temp_millic=60555 temp_c=60.5 policy=power_allocator$' ||
  fail 'thermal status'

snapshot="$RUNTIME_ROOT/cpu/test.snapshot"
cpu_env snapshot "$snapshot"
cpu_env apply performance
assert_equal performance "$(sed -n '1p' "$CPUFREQ_ROOT/policy0/scaling_governor")" \
  'policy0 apply'
assert_equal performance "$(sed -n '1p' "$CPUFREQ_ROOT/policy4/scaling_governor")" \
  'policy4 apply'

if cpu_env apply userspace; then fail 'unsupported governor accepted'; fi
assert_equal performance "$(sed -n '1p' "$CPUFREQ_ROOT/policy0/scaling_governor")" \
  'failed apply changed policy'

cpu_env restore "$snapshot"
assert_equal ondemand "$(sed -n '1p' "$CPUFREQ_ROOT/policy0/scaling_governor")" \
  'policy0 restore'
assert_equal ondemand "$(sed -n '1p' "$CPUFREQ_ROOT/policy4/scaling_governor")" \
  'policy4 restore'
[ ! -e "$snapshot" ] || fail 'snapshot not removed after restore'

grep -q 'CPU_POLICY="${PLUMOS_PYXEL_CPU_POLICY:-performance}"' \
  "$ROOT_DIR/scripts/build-pyxel-bubble.sh" || fail 'Pyxel policy not wired'
grep -q 'snapshot "$CPU_SNAPSHOT"' "$ROOT_DIR/scripts/build-pyxel-bubble.sh" ||
  fail 'Pyxel snapshot not wired'
grep -q 'restore_cpu_policy' "$ROOT_DIR/scripts/build-pyxel-bubble.sh" ||
  fail 'Pyxel restore not wired'
grep -q 'cpu_policy=$2' \
  "$ROOT_DIR/package/frontend-bubble/plumos/bin/plumos-retroarch-launch" ||
  fail 'RetroArch --cpu not wired'
grep -q 'PLUMOS_PICOARCH_CPU_POLICY:-ondemand' \
  "$ROOT_DIR/package/picoarch-bubble/plumos/bin/plumos-picoarch-launch" ||
  fail 'PicoArch policy not wired'

printf 'bubble_cpu_control=result-ok policies=retroarch,picoarch,standalone,pyxel\n'
