#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
probe=$repo_root/scripts/probe-bubble-drm-properties.c

grep -q 'open(device, O_RDONLY | O_CLOEXEC)' "$probe"
! grep -q 'open(device, O_RDWR' "$probe"
grep -q 'drmModeGetResources' "$probe"
grep -q 'drmModeGetCrtc' "$probe"
grep -q 'drmModeGetConnector' "$probe"
grep -q 'drmModeGetPlaneResources' "$probe"
grep -q 'drmModeGetPlane' "$probe"
grep -q 'drmModeGetFB2' "$probe"
grep -q 'drmModeGetFB(fd, fb_id)' "$probe"
grep -q 'IN_FORMATS' "$probe"
grep -q 'plane-modifier' "$probe"
grep -q 'pitch=%u' "$probe"

if grep -Eq 'drmModeSetCrtc|drmModeSetPlane|drmModePageFlip|DRM_IOCTL_MODE_ATOMIC|DRM_IOCTL_MODE_DIRTYFB' "$probe"; then
    echo 'Bubble DRM inventory probe contains a display-mutating call' >&2
    exit 1
fi

printf '%s\n' 'bubble_drm_read_only_probe=result-ok resources=connector,crtc,plane,format,stride,modifier mutation=none'
