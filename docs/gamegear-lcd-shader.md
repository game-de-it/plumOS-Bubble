# Game Gear LCD shader

A RetroArch shader that reproduces the panel in a real Game Gear rather than
applying a generic LCD filter.

    configs/retroarch/shaders/gamegear-lcd.glslp
    configs/retroarch/shaders/gamegear-lcd-response.glsl
    configs/retroarch/shaders/gamegear-lcd-panel.glsl

## Why GLSL and not slang

`scripts/build-bubble-retroarch.sh` configures RetroArch with
`--enable-opengles --disable-opengl_core`, so this device has no glcore or
Vulkan context and the slang path does not exist on it. GLSL is the only
format that will load.

## What it models

**Response.** The Game Gear's STN panel is slow, and that is the single most
recognisable thing about the screen: anything that moves leaves a trail. The
response is also asymmetric - a cell falls to dark noticeably slower than it
rises to light - so a bright sprite crossing a dark background drags a tail
behind it while its leading edge stays reasonably crisp. A fast-moving object
also never quite reaches full brightness, which is correct rather than a bug.

RetroArch's GLSL path exposes the previous input frames rather than a feedback
buffer, so this is a four-tap weighted history instead of an IIR. That is
enough to read as smear without becoming a double image.

**Cell structure.** A smooth falloff from the centre of each cell, not a
border. A hard border does not survive this scale: at an exact 3x a cell is
three output pixels, so pixel centres only ever land at 1/6, 1/2 and 5/6 of
it, and a narrow edge band is never sampled at all. The falloff is also closer
to how a real cell looks.

**STN gamut.** The panel is washed out rather than dark. The floor lifts
because the backlight leaks through and the ceiling never reaches white, so
this is applied as a contrast range rather than a gamma curve, with a little
desaturation on top.

**Backlight.** The CCFL sat along one edge, so the light falls away from it
and the far corners are dimmest. A real Game Gear photograph is never evenly
lit. Kept gentle - the point is only that it is not flat.

## Subpixels

The shader can draw the RGB stripe, but **it is off by default**, because at
the scale this device presents Game Gear content it does more harm than good.
160x144 at 3x gives three output pixels per cell, which is exactly one per
subpixel, so any strength at all produces hard vertical colour fringing rather
than the impression of subpixels. On a real panel your eye integrates them;
at 3x there is nothing to integrate.

Raise `Subpixel strength` if you are running at a much larger scale, where it
starts to behave.

## Parameters

Adjustable from RetroArch's shader parameters menu.

| Parameter | Default | What it does |
|---|---:|---|
| LCD rise speed | 0.62 | how fast a cell brightens; lower smears more |
| LCD fall speed | 0.34 | how fast it darkens; the asymmetry is the trail |
| Subpixel strength | 0.00 | RGB stripe; see above |
| Cell gap | 0.35 | how strongly the cell matrix shows |
| Black level | 0.085 | how far the backlight lifts black |
| White level | 0.92 | how far short of white the panel stops |
| Saturation | 0.88 | |
| Panel gamma | 0.92 | |
| Backlight unevenness | 0.28 | falloff away from the lamp |
| Backlight tint | 0.30 | the light is not white |

## Installing and using it

`scripts/build-bubble-retroarch.sh` stages the three files into
`factory-defaults/shaders`, and `plumos-retroarch-launch` copies any that are
missing into `config/shaders`, which is where `video_shader_dir` points. They
are copied rather than linked and never overwritten, so an edited preset
survives an update.

`video_shader_enable` is `false` in the shipped config, so nothing changes
until it is asked for. In a running game: **RetroArch menu > Shaders > Load
Preset > gamegear-lcd.glslp**, then *Apply*. `auto_shaders_enable` is on, so
saving the preset as a core or content preset from that menu will bring it
back automatically next time.

## Verifying it

`scripts/preview-gamegear-lcd.py` reimplements both passes in numpy and writes
before and after images, including a moving block that shows the response
trail. It is how the look was arrived at, and it runs on a build machine.

It does **not** compile the GLSL - there is no validator in the tools image -
so a device run is still what proves the shader loads. If it does not, the
reason will be in RetroArch's log; a GLSL compile failure names the line.
