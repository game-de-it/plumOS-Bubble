# Bubble headphone and suspend physical acceptance

Date: 2026-09-10 JST (device UTC log date 2026-09-09)

## Scope

This validation closes `BUB-P4-A03`: physical headphone insertion/removal,
audio-route recovery after deep suspend, and PCM/display cleanup after normal
game exit. It does not close the mixer-control inventory or the separate
five-minute/XRUN matrix in `BUB-P4-A01` and `BUB-P4-A02`.

The normal frontend route launched `BC Racers (USA).32x` with
`retroarch:picodrive`. RetroArch PID 3941 owned the RK817 playback PCM at
48,000 Hz, stereo, `S32_LE`, with a 768-frame period and 3,072-frame buffer.

## Physical route sequence

1. The user inserted wired headphones while the game was playing and heard the
   game music through the headphones.
2. The user removed them without stopping the game. Audio moved to the internal
   speaker. PCM remained `RUNNING`, its owner PID remained 3941, and `hw_ptr`
   advanced from 2,251,516 to 8,074,888.
3. The user reinserted the headphones and confirmed that output returned to
   them.
4. With music still playing, the user selected Sleep from the game power menu.
   The log recorded `stage=begin` at `19:01:33Z`, deep-suspend entry at
   `19:01:35Z`, resume at `19:01:44Z`, and successful background network
   restoration.
5. After resume, music again played through the headphones while the internal
   speaker remained silent. PCM was `RUNNING` with the same format and owner;
   the hardware pointer continued advancing. Wi-Fi also returned at
   `192.168.10.101/24`.
6. The user exited with the normal SELECT+START route. RetroArch and its launch
   wrappers exited, playback PCM changed to `closed`, and the frontend PID 335
   became the only `/dev/dri/card0` owner.

## Result and boundaries

Insertion, removal, reinsertion, suspend/resume routing, normal game exit, PCM
release, and frontend display reacquisition passed on the physical Bubble.
The RK817 driver did not expose a separate readable jack switch or hardware
mixer controls through the current ALSA control interface, so the physical
audible route transition is the acceptance evidence here. Exact jack-detect
inventory remains part of `BUB-P4-A01`; multi-runtime duration and XRUN proof
remain part of `BUB-P4-A02`.
