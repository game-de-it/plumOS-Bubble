# Bubble N64 audio performance acceptance

Date: 2026-09-10 JST

## Scope

The user launched the same frontend-visible content,
`Mario Kart 64 [V1.0].z64`, through both packaged N64 profiles after a normal
device reboot:

- `retroarch:parallel_n64`
- `retroarch:mupen64plus_next`

Both launch commands carried `--cpu performance`. The device read back the
`performance` governor and 1,992,000 kHz throughout each run. The normal
frontend idle policy remained `ondemand` before launch.

## ParaLLEl N64

PCM opened as 48 kHz, stereo, S32_LE with a 768-frame period and 3,072-frame
buffer. During a 30-second one-second-interval trace it remained `RUNNING`
except for one observed `XRUN`; five trigger-time values showed that the audio
stream was restarted around the transient. Outside the XRUN, sampled
`avail_max` remained below the buffer size. A load snapshot showed 90% total
CPU idle and the SoC temperature was approximately 46 C.

The user reported that ordinary racing was comparatively stable. Audible
skipping remained at the player-select screen and similar transitions.

## Mupen64Plus-Next

The same PCM format and buffer were used. The 30-second trace observed one
`PREPARED` sample, one `XRUN`, and ten trigger-time changes. A load snapshot
showed 82% total CPU idle and the SoC temperature was approximately 49 C.

The user again heard skipping at player select and when another character
appeared, while ordinary racing remained usable and did not collapse.

## Decision

The previous N64 failure, where both cores stayed `PREPARED` with a stationary
hardware pointer and no audio, is resolved. N64 now uses the `performance`
policy by default and restores the normal policy after exit. The remaining
transients occur even at maximum CPU frequency with substantial system-wide
idle capacity, and are therefore recorded as core/scene latency rather than a
general four-core capacity failure.

ParaLLEl had fewer stream restarts in the equivalent physical test and remains
the default N64 profile. This is usable-with-known-transients evidence, not an
XRUN-free acceptance. `BUB-P4-A02` and the wider `BUB-P6-10` matrix remain open.
