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

The row gap is much stronger than the column gap, because that is what a
photograph of a real panel shows: the gap between rows is a whole cell
boundary, while the columns are split by subpixels. The screen reads as fine
horizontal lines with colour texture between them.

Both the grid and the stripe are normalised to unit mean. Without that they
are a brightness cut rather than a structure, and turning the grid up simply
makes the panel dark.

**STN gamut.** The panel is washed out rather than dark. The floor lifts
because the backlight leaks through and the ceiling never reaches white, so
this is applied as a contrast range rather than a gamma curve, with a little
desaturation on top.

**The blue cast, which is not subtle.** Between the CCFL and the STN stack the
whole panel sits blue-cyan: light greys come out pale blue and never white.
It is the first thing you notice in a photograph of a real Game Gear, and
leaving it out is what makes an LCD filter look generic. A source white ends
up around R:G:B of 1 : 1.1 : 1.3.

**Backlight.** The CCFL sat along one edge, so the light falls away from it
and the far corners are dimmest. A real Game Gear photograph is never evenly
lit. Kept gentle - the point is only that it is not flat.

## Subpixels

160x144 at 3x gives three output pixels per cell, which is exactly one per
subpixel, so the stripe can be drawn honestly here - and on a real panel it is
plainly visible, so it is on.

Two details make it read as subpixels rather than as colour fringing. The
channel peaks sit at 1/6, 1/2 and 5/6 of the cell rather than 0, 1/3 and 2/3,
so at an exact 3x a pixel centre lands on each peak and the three pixels of a
cell really are red, green and blue. And the masks are cosines rather than
triangles: three cosines at 120 degrees sum to a constant, so the stripe
shifts colour across the cell without also rippling the brightness, and their
overlap stands in for the diffuser over a real panel.

Turn `Subpixel strength` down if the source is being scaled by something other
than an exact 3x, where the phase no longer lines up.

## Parameters

Adjustable from RetroArch's shader parameters menu.

| Parameter | Default | What it does |
|---|---:|---|
| LCD rise speed | 0.62 | how fast a cell brightens; lower smears more |
| LCD fall speed | 0.34 | how fast it darkens; the asymmetry is the trail |
| Subpixel strength | 0.55 | RGB stripe; see above |
| Row gap | 0.55 | the horizontal lines, the dominant structure |
| Column gap | 0.18 | the vertical cell boundary, much weaker |
| Black level | 0.10 | how far the backlight lifts black |
| White level | 0.90 | how far short of white the panel stops |
| Saturation | 0.82 | |
| Panel gamma | 0.90 | |
| Backlight unevenness | 0.28 | falloff away from the lamp |
| Blue cast | 0.55 | how far towards blue-cyan the panel sits |

## Installing and using it

`scripts/build-bubble-retroarch.sh` stages the three files into
`factory-defaults/shaders`, and `plumos-retroarch-launch` copies any that are
missing into `config/shaders`, which is where `video_shader_dir` points. They
are copied rather than linked and never overwritten, so an edited preset
survives an update.

`video_shader_enable` remains `false` in the persistent shipped config.
`plumos-retroarch-launch` enables the shader and selects the KMS/EGL/GLES path
for `system=gamegear` only, then passes `gamegear-lcd.glslp` with RetroArch's
`--set-shader` option. Other systems retain their existing rendering route and
the user's persistent configuration is not rewritten.

Do not save this as a core preset. Genesis Plus GX and PicoDrive also run
Master System, Mega Drive and Sega CD content, so a core preset would leak the
Game Gear panel into those systems. For device diagnosis only,
`PLUMOS_GAMEGEAR_LCD_PRESET=panel-only` selects the one-pass preset and
`PLUMOS_GAMEGEAR_LCD_PRESET=off` restores the unshaded route for that launch.

## Verifying it

`scripts/preview-gamegear-lcd.py` reimplements both passes in numpy and writes
before and after images, including a moving block that shows the response
trail. It is how the look was arrived at, and it runs on a build machine.

It does **not** compile the GLSL - there is no validator in the tools image -
so a device run is still what proves the shader loads. If it does not, the
reason will be in RetroArch's log; a GLSL compile failure names the line.
