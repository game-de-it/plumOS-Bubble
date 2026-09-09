# Bubble DRM read-only inventory (2026-09-10)

対象は起動中のGKD Bubble (`root@192.168.10.101`)。通常FEを停止せず、
`scripts/probe-bubble-drm-properties.c` をAArch64向けにビルドして一時的に
`/tmp`へ置き、`/dev/dri/card0`を`O_RDONLY`で開いてGET系ioctlだけを実行した。
`UNIVERSAL_PLANES`と`ATOMIC` client capはprobe自身のfdにだけ設定しており、
CRTC、plane、framebuffer、connectorの状態は変更していない。

## Display ownership

probe実行前後で`/proc/*/fd`から`/dev/dri/card0`所有者を採取した。

```text
BEFORE pid=338 comm=plumos-controll
PROBE_RC=0
AFTER  pid=338 comm=plumos-controll
```

FEは継続稼働し、connector sysfsも実行後に`connected`、`640x480`だった。
FE/emulatorを同時描画させず、master取得、modeset、page flip、plane更新は行っていない。

## Active scanout

```text
device=/dev/dri/card0 open_mode=read-only crtcs=3 connectors=1 encoders=2
connector id=154 name=DSI-1 connection=connected encoder=153
mode=640x480 clock_khz=27000 htotal=900 vtotal=500 vrefresh=60
active_crtc=71 active_plane=57 plane_type=primary
framebuffer=640x480 depth=24 bpp=32 pitch=2560
source=640x480 destination=640x480 alpha=65535 rotation=rotate-0
```

kernelは`GETFB2`に`EINVAL`を返すため、active framebufferの寸法、depth、bpp、
strideはread-onlyのlegacy `GETFB`へfallbackして採取した。FE rendererはこのbufferを
`drmModeAddFB(width, height, 24, 32, pitch, handle)`で登録しており、active primary
plane 57の`IN_FORMATS`では32-bit 24-depth形式`XR24` (`XRGB8888`)がlinear
modifierだけに対応する。従ってactive scanoutは`XR24`、pitch 2560 bytes、
linear modifier (`0x0000000000000000`) と確定できる。double bufferのためFB IDは
frameごとに変わり得るが、寸法・形式・stride・modifierは同一である。

## Resources and formats

- CRTC: 71（active）、87、103（inactive）の3本。
- primary plane: 57（active）、73、89。overlay plane: 105、119、133。
  cursor planeは公開されていない。
- primary 57/73は`XR24 AR24 XB24 AB24 RG24 BG24 RG16 BG16`、primary 89は
  それらにYUV/NV形式を加えた16形式を公開する。
- overlay 105/119/133はRGBとYUV/NV形式を公開する。119/133はRockchip AFBC
  modifier群とlinearを公開するが、現在のscanoutには使われていない。
- DSI-1が公開するmodeは640x480の1個。kernel報告のphysical sizeは135x216 mm、
  connector brightness/contrast/saturation/hueは各50だった。

## Reproduction

```sh
docker run --rm --platform linux/arm64 -v "$PWD:/work" -w /work \
  plumos-bubble-tools:dev sh -lc \
  'gcc -std=gnu99 -O2 -Wall -Wextra $(pkg-config --cflags libdrm) \
   scripts/probe-bubble-drm-properties.c -o /tmp/probe-bubble-drm-properties \
   $(pkg-config --libs libdrm)'
```

実機ではfrontend componentの`libdrm.so.2`だけを一時的なlibrary pathに指定した。
probeはapp-layerへデプロイせず、mutable設定、ROM、save、metadataへ変更を加えていない。
