# Bubble frontend display pacing (2026-09-10)

`BUB-P4-D03` was measured on the physical GKD Bubble through the normal,
PID 1-supervised frontend route. No emulator or second display owner was
running. The active frontend exclusively held `/dev/dri/card0` and
`/dev/input/event2`.

The opt-in `PLUMOS_DISPLAY_TRACE_PATH` instrument records a timestamp only
after the blocking DRM page-flip event completes. It also associates a physical
input read with the first completed presentation containing that action. The
trace was written to tmpfs so storage latency was not part of the result. The
instrument is disabled during normal frontend operation.

The user pressed left/right separately and then held a direction for about two
seconds. `scripts/analyze-bubble-display-trace.py` reported:

```text
bubble_display_trace=result-ok frames=73 input_samples=18
input_to_present_us=min:16308,median:30905,p95:38098,max:38098
active_pacing=frames:46,duration_us:983254,average_fps:45.766,interval_p95_us:33464,interval_max_us:33546,one_vblank:31,two_vblank:14,other:0
observed_vblank_hz=60.042
```

The kernel mode inventory independently reports a 27 MHz pixel clock with
900x500 totals, exactly 60 Hz. The completed page-flip intervals confirm this
on the running frontend: every active interval was either one 60 Hz vblank
(about 16.7 ms) or two vblanks (about 33.3 ms). The longest continuous burst
therefore averaged 45.8 presented frames/s; 31 of 45 intervals met the next
vblank and 14 missed one vblank.

Input-read to completed-scanout latency was 16.3-38.1 ms with a 30.9 ms
median. The physical panel scans the newly selected buffer during the following
0-16.7 ms, so the corresponding software-derived visible-window estimate is
16.3-54.8 ms. LCD response time itself was not measured with a photodiode or
high-speed camera and is intentionally not included in that estimate.

After capture, the tmpfs enable marker was removed and the instrumented process
was terminated normally. PID 1 started exactly one ordinary frontend without
`PLUMOS_DISPLAY_TRACE_PATH`; no validation hold or second renderer remained.
