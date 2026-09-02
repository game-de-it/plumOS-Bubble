# Bubble physical input map

Date: 2026-09-02

## Evidence boundary

The map below is based on an ordered physical press capture from the running
Bubble, not on key-name assumptions. The stock kernel exposes the built-in
controller as `retrogame_joypad` on `event2` and `js0`; volume is `event1`, and
power is `event0`. The runtime DT labels and a `JSIOCGBTNMAP`/`JSIOCGAXMAP`
probe independently agree with the capture.

The raw captures are deliberately ignored artifacts rather than release files:

| Capture | SHA-256 |
| --- | --- |
| `event0.bin` | `9b815696bb713123e2f5a87108b52ee8c79ca840fd316d2fc2b173ebb291d9b8` |
| `event1.bin` | `fc2d6d2b84f77f86b3fea5f19f464922a1ba3358b381adfd7e3e1fa11c886734` |
| `event2.bin` | `8ca1b6683a5f3edb990ff509c57c83a2cf02f15df591530128838866aba01021` |
| `r-retry-event2.bin` | `1baa2423437028af6875dee2804f3cfcc3ec229d2a6b6314cc9a7170a75842e9` |

The machine-readable source of truth is
`configs/input/bubble-controller-map.json`. The probe reports four joystick
axes and eighteen buttons.

## Physical controller

| Physical control | evdev | js | plumOS assignment |
| --- | ---: | ---: | --- |
| D-pad Up/Down/Left/Right | 544/545/546/547 | 13/14/15/16 | game and menu directions |
| A | 305 `BTN_EAST` | 1 | logical A, menu confirm |
| B | 304 `BTN_SOUTH` | 0 | logical B, menu back |
| X | 307 `BTN_NORTH` | 2 | logical X |
| Y | 308 `BTN_WEST` | 3 | logical Y |
| Select / Start | 314/315 | 8/9 | logical Select/Start; RetroArch Select+Start exit |
| L / R | 310/311 | 4/5 | logical L/R |
| L2 / R2 | 312/313 | 6/7 | digital logical L2/R2 |
| left stick | `ABS_X/ABS_Y` | axes 0/1 | left analog; FE navigation uses this stick only |
| L3 | 317 | 11 | logical L3 |
| right stick | `ABS_RX/ABS_RY` | axes 2/3 | right analog |
| R3 | 318 | 12 | logical R3 |
| Function1 | 704 `BTN_TRIGGER_HAPPY1` | 17 | RetroArch screenshot; PicoArch menu fallback |
| Function2 | 316 `BTN_MODE` | 10 | emulator menu |

The important face-button rule is physical-label preservation. In particular,
Bubble's physical A is `BTN_EAST`, so mapping `BTN_SOUTH` to logical A reverses
A/B. PicoArch carried that V90S assumption and was corrected here. Physical X
and Y were already label-correct.

PicoArch has no screenshot action. It therefore treats Function1 as a second
menu path, while Function2 remains the normal menu button. This is an explicit
runtime fallback, not evidence that the two raw buttons are identical.

## System-owned keys

| Physical control | evdev | Owner |
| --- | ---: | --- |
| Volume down / up | 114/115 on `event1` | persistent hardware-volume service |
| Power | 116 on `event0` | system power policy |

These three keys must not be exposed as game buttons. A short power press was
captured only to identify the code; destructive long-press behavior is outside
the emulator input contract.

## Acceptance status

Raw identity, evdev codes, joystick indices, axes, and the A/B cause are
physically confirmed. Configuration/build tests prove the intended frontend,
RetroArch, and PicoArch mappings. Actual game behavior remains a separate
per-runtime physical gate, including both sticks, L3/R3, both Function keys,
menu confirm/back, and normal exit. Standalone emulator mappings also require
system-specific checks because six-button Saturn and PlayStation layouts must
not be inferred from the generic RetroPad labels.
