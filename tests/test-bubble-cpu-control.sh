#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d /tmp/plumos-bubble-cpu-test.XXXXXX)"
CPUFREQ_ROOT="$TEST_ROOT/sys/devices/system/cpu/cpufreq"
THERMAL_ROOT="$TEST_ROOT/sys/class/thermal"
RUNTIME_ROOT="$TEST_ROOT/run/plumos"
CPU_CONTROL="$ROOT_DIR/package/frontend-bubble/plumos/bin/plumos-cpu-control"
GGFE_LAUNCH="$ROOT_DIR/package/frontend-bubble/plumos/bin/plumos-ggfe-launch"
SYSTEMS="$ROOT_DIR/package/frontend-bubble/plumos/config/frontend/systems.json"

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
jq -e '.systems[] | select(.id == "n64") |
  .default_cpu_policy == "performance" and
  .launch_profiles == ["retroarch:parallel_n64", "retroarch:mupen64plus_next"]' \
  "$SYSTEMS" >/dev/null || fail 'N64 performance policy not wired for both cores'
grep -q 'PLUMOS_PICOARCH_CPU_POLICY:-ondemand' \
  "$ROOT_DIR/package/picoarch-bubble/plumos/bin/plumos-picoarch-launch" ||
  fail 'PicoArch policy not wired'

grep -q 'CPU_POLICY=${PLUMOS_GGFE_CPU_POLICY:-performance}' "$GGFE_LAUNCH" ||
  fail 'GGFE policy not wired'
grep -q 'snapshot "$CPU_SNAPSHOT"' "$GGFE_LAUNCH" ||
  fail 'GGFE snapshot not wired'
grep -q 'restore_cpu_policy' "$GGFE_LAUNCH" ||
  fail 'GGFE restore not wired'
grep -q "trap 'cleanup_ggfe 143' TERM" "$GGFE_LAUNCH" ||
  fail 'GGFE TERM cleanup not wired'

# Exercise the launcher contract with a fake CPU controller.  A non-zero child,
# an apply failure, and TERM must all restore the pre-launch governor.
GGFE_ROOT="$TEST_ROOT/ggfe-root"
GGFE_RUNTIME="$TEST_ROOT/run/ggfe-test"
GGFE_ACTIONS="$TEST_ROOT/ggfe-actions"
GGFE_CPU_STATE="$TEST_ROOT/ggfe-cpu-state"
GGFE_READY="$TEST_ROOT/ggfe-ready"
FAKE_BB="$TEST_ROOT/fake-busybox"
mkdir -p "$GGFE_ROOT/bin" "$GGFE_ROOT/logs" "$GGFE_RUNTIME"
cp "$GGFE_LAUNCH" "$GGFE_ROOT/bin/plumos-ggfe-launch"

cat >"$FAKE_BB" <<'EOF'
#!/bin/sh
if [ "${1:-}" = usleep ]; then
  /usr/bin/perl -e 'select undef, undef, undef, $ARGV[0] / 1000000' "$2"
  exit 0
fi
exec "$@"
EOF
cat >"$GGFE_ROOT/bin/plumos-cpu-control" <<'EOF'
#!/bin/sh
case "$1" in
  snapshot)
    printf 'snapshot\n' >>"$FAKE_CPU_ACTIONS"
    cp "$FAKE_CPU_STATE" "$2"
    ;;
  apply)
    printf 'apply:%s\n' "$2" >>"$FAKE_CPU_ACTIONS"
    [ "${FAKE_APPLY_FAIL:-0}" -eq 0 ] || exit 1
    printf '%s\n' "$2" >"$FAKE_CPU_STATE"
    ;;
  restore)
    printf 'restore\n' >>"$FAKE_CPU_ACTIONS"
    cp "$2" "$FAKE_CPU_STATE"
    rm -f "$2"
    ;;
  *) exit 2 ;;
esac
EOF
cat >"$GGFE_ROOT/bin/plumos-ggfe" <<'EOF'
#!/bin/sh
[ "$(sed -n '1p' "$FAKE_CPU_STATE")" = performance ] || exit 99
printf 'ready\n' >"$FAKE_GGFE_READY"
trap 'exit 0' TERM
if [ "${FAKE_GGFE_MODE:-exit}" = wait ]; then
  while :; do sleep 1; done
fi
exit "${FAKE_GGFE_RC:-7}"
EOF
chmod +x "$FAKE_BB" "$GGFE_ROOT/bin/plumos-cpu-control" \
  "$GGFE_ROOT/bin/plumos-ggfe" "$GGFE_ROOT/bin/plumos-ggfe-launch"

run_fake_ggfe() {
  PLUMOS_ROOT="$GGFE_ROOT" \
  PLUMOS_RUNTIME_ROOT="$GGFE_RUNTIME" \
  PLUMOS_BUSYBOX="$FAKE_BB" \
  PLUMOS_INPUT_EVENT=/dev/null \
  PLUMOS_FRONTEND_LIB_DIR="$GGFE_ROOT/lib" \
  FAKE_CPU_ACTIONS="$GGFE_ACTIONS" \
  FAKE_CPU_STATE="$GGFE_CPU_STATE" \
  FAKE_GGFE_READY="$GGFE_READY" \
  FAKE_APPLY_FAIL="${FAKE_APPLY_FAIL:-0}" \
  FAKE_GGFE_MODE="${FAKE_GGFE_MODE:-exit}" \
  FAKE_GGFE_RC="${FAKE_GGFE_RC:-7}" \
    "$FAKE_BB" sh "$GGFE_ROOT/bin/plumos-ggfe-launch"
}

printf 'ondemand\n' >"$GGFE_CPU_STATE"
: >"$GGFE_ACTIONS"
set +e
FAKE_GGFE_RC=7 run_fake_ggfe
ggfe_rc=$?
set -e
assert_equal 7 "$ggfe_rc" 'GGFE child status'
assert_equal ondemand "$(sed -n '1p' "$GGFE_CPU_STATE")" \
  'GGFE normal restore'
assert_equal 'snapshot apply:performance restore' \
  "$(tr '\n' ' ' <"$GGFE_ACTIONS" | sed 's/ $//')" 'GGFE normal actions'

printf 'ondemand\n' >"$GGFE_CPU_STATE"
: >"$GGFE_ACTIONS"
set +e
FAKE_APPLY_FAIL=1 run_fake_ggfe
ggfe_rc=$?
set -e
assert_equal 1 "$ggfe_rc" 'GGFE apply failure status'
assert_equal ondemand "$(sed -n '1p' "$GGFE_CPU_STATE")" \
  'GGFE apply failure restore'
assert_equal 'snapshot apply:performance restore' \
  "$(tr '\n' ' ' <"$GGFE_ACTIONS" | sed 's/ $//')" \
  'GGFE apply failure actions'

printf 'ondemand\n' >"$GGFE_CPU_STATE"
: >"$GGFE_ACTIONS"
rm -f "$GGFE_READY"
set +e
PLUMOS_ROOT="$GGFE_ROOT" \
PLUMOS_RUNTIME_ROOT="$GGFE_RUNTIME" \
PLUMOS_BUSYBOX="$FAKE_BB" \
PLUMOS_INPUT_EVENT=/dev/null \
PLUMOS_FRONTEND_LIB_DIR="$GGFE_ROOT/lib" \
FAKE_CPU_ACTIONS="$GGFE_ACTIONS" \
FAKE_CPU_STATE="$GGFE_CPU_STATE" \
FAKE_GGFE_READY="$GGFE_READY" \
FAKE_APPLY_FAIL=0 \
FAKE_GGFE_MODE=wait \
FAKE_GGFE_RC=7 \
  "$FAKE_BB" sh "$GGFE_ROOT/bin/plumos-ggfe-launch" &
ggfe_launcher_pid=$!
set -e
count=0
while [ ! -s "$GGFE_READY" ] && [ "$count" -lt 50 ]; do
  sleep 0.1
  count=$((count + 1))
done
[ -s "$GGFE_READY" ] || fail 'GGFE signal fixture did not start'
kill -TERM "$ggfe_launcher_pid"
set +e
wait "$ggfe_launcher_pid"
ggfe_rc=$?
set -e
assert_equal 143 "$ggfe_rc" 'GGFE TERM status'
assert_equal ondemand "$(sed -n '1p' "$GGFE_CPU_STATE")" \
  'GGFE TERM restore'
assert_equal 'snapshot apply:performance restore' \
  "$(tr '\n' ' ' <"$GGFE_ACTIONS" | sed 's/ $//')" 'GGFE TERM actions'

printf 'bubble_cpu_control=result-ok policies=retroarch,picoarch,standalone,pyxel,ggfe\n'
