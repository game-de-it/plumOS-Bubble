#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
patch=$repo_root/patches/retroarch/018-bubble-alsa-menu-drop-prepare.patch

test -f "$patch"
grep -Fq '+   ret = snd_pcm_drop(alsa->pcm);' "$patch"
grep -Fq '+   ret = snd_pcm_prepare(alsa->pcm);' "$patch"
grep -Fq 'hardware pointer, permanently blocking the first resumed write' "$patch"
grep -Fq 'Bubble PCM dropped for menu pause' "$patch"
grep -Fq 'Bubble PCM prepared after menu' "$patch"

echo 'bubble_retroarch_audio_resume=result-ok'
