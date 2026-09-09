# Bubble NES five-minute audio acceptance

Date: 2026-09-10 JST (device UTC log date 2026-09-09)

## Route and method

The user launched `Akumajou Densetsu.nes` through the normal frontend route
with `retroarch:quicknes`, removed the headphones, and confirmed audible music
from the internal speaker. RetroArch PID 5710 owned the RK817 PCM.

From `19:06:31Z`, the device was sampled every five seconds for 301 seconds.
The user deliberately exercised fast-forward and opened/closed the RetroArch
menu during the run. This was a live gameplay test, not idle audio playback.

## Result

```text
samples=60
state_not_running=0
owner_changes=0
hardware_pointer_stalls=0
max_avail=1861
buffer_size=3072
kernel_xrun_delta=0
format=S32_LE
channels=2
rate=48000
period_size=768
```

The hardware pointer advanced at every sample. Its displayed counter wrapped
once and continued advancing; it did not stall. At the end of the monitor PCM
remained `RUNNING` with the same owner and parameters. The user confirmed that
controls, video, and sound remained normal throughout, including after
fast-forward and the menu round trip.

This closes the representative five-minute speaker run and corroborates the
existing FCEUmm result. It does not by itself close `BUB-P4-A02`: the two N64
routes previously remained `PREPARED` with a stationary hardware pointer, and
the remaining runtime audio matrix is tracked separately.
