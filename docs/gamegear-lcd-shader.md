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

The grid is normalised to unit mean and the stripe to unit luminance, so
structure costs contrast rather than light. That pushes peaks above one, which
the backlight saturation below absorbs.

**Backlight saturation.** The output is passed through `1 - exp(-k*x)` rather
than being clamped. A cell cannot pass more light than there is behind it, so
the response rolls off. This is also the brightness control: it lifts the
average, which is what the structure takes away, while the peaks approach one
instead of being cut flat there. Clamping instead flattened all three channels
together, which cost the highlights their blue cast as well as their detail.

**STN gamut.** The panel is washed out rather than dark. The floor lifts
because the backlight leaks through and the ceiling never reaches white, so
this is applied as a contrast range rather than a gamma curve, with a little
desaturation on top.

**SEGA panel colour.** Blue content is washed out selectively by the original
STN colour stack, but it must remain recognisably blue. Whites retain a faint
green-cyan cast from the lamp rather than becoming modern neutral white. The
Majesco panel is a separate, warmer/yellower variant and is intentionally not
folded into this first SEGA profile.

**Backlight.** The CCFL sat along one edge, so the light falls away from it
and the far corners are dimmest. A real Game Gear photograph is never evenly
lit. Kept gentle - the point is only that it is not flat.

## Scaling: 4:3 non-square dots without moire

The SEGA profile maps the 160x144 image to the Bubble's full 640x480 aperture.
One source dot is therefore 4.00 output pixels across and 3.33 pixels down: it
is a horizontal rectangle, not a square.

Point sampling the panel structure at this ratio is wrong. Three RGB elements
cannot be assigned evenly to four output-pixel centres, and the 3.33x row
period beats against the output grid. The panel pass instead integrates the
coverage of each RGB element and the row-edge curve across the physical area
of one output pixel. The RGB integral is analytic, so red, green and blue have
equal total coverage. The row integral removes the slow interference pattern
without deleting the intended fine horizontal structure.

The implementation avoids `fwidth`/derivatives because this device uses GLSL
ES 1.00. Exact 3x remains available as a diagnostic comparison with
`PLUMOS_GAMEGEAR_LCD_GEOMETRY=integer3x`; aligned 3x/6x element layouts retain
the original point-sampled appearance.

## Colour: the blue filter is the weak one

Matched against a photograph of the hardware showing Sonic 2's title screen,
sampling by source colour so like is compared with like. The picture from the
real panel is not simply less saturated than this filter's - it is selective:

| Source colour | Device chroma | Filter chroma, before |
|---|---:|---:|
| background, a pure blue in the ROM | 0.15 | 0.86 |
| the light blue of the letters | 0.03 | 0.60 |
| the red of the banner | 0.60 | 0.45 |

Blue arrives all but neutral while red arrives *more* saturated than the
filter was drawing it. No global saturation does that; turning it down to grey
out the background takes the banner with it. Over the same region of the
screen, the device's mean hue is R:G:B 0.944 : 0.999 : 1.000 - very nearly
neutral - against 0.635 : 0.683 : 1.000 here.

So `Weak blue filter` washes blue content specifically. Two models were
measured against the photograph and only one fits:

- adding light for blue, as a leaky filter would: matching the background's
  chroma at 0.15 needs a strength that lifts it to within 1.5x of white, and
  on the real screen "PRESS START BUTTON" stays plainly legible against that
  background. Rejected.
- washing the colour out while putting the luminance back: chroma 0.16
  against the measured 0.15, brightness 0.32 against 0.35, white-to-background
  contrast 2.6 against 2.4. Adopted.

The lamp's colour was measured too, rather than assumed. White on the real
panel photographs at R:G:B 0.92 : 1.00 : 0.95 - a faint green, which is what
an STN over a CCFL looks like. This shader had a blue cast, the wrong
direction, and part of why its blue was so much stronger than the device's.

Caveats worth keeping in mind: this is one unit, and a faulty one - the right
two thirds of its screen wash out, so only the left third was sampled - and
the camera's white balance cannot be pinned down. The chroma findings survive
all of that, because they are ratios within a single frame. The absolute
brightness does not: the same source colour measures anywhere from 0.27 to
0.45 across that screen, so the tone curve was left where the eye had put it
rather than fitted to a number.

## Element visibility and the tone curve

Two settings fought each other here, and the device settled it.

The stripe's three bands do not carry equal luminance: green carries most of
it and blue almost none, so the raw stripe is about 55% brighter on green than
on blue. Dividing that out makes the bands differ in hue alone. That was added
to stop grey areas banding when the triad was two cells wide, and at six
pixels a period it was the right call.

At the physical pitch it is the wrong one. At exact 3x an element is one
output pixel; at 4:3 the three elements share four output pixels through area
coverage. In both cases the small luminance ripple is part of what makes the
elements visible rather than a flat wash. `Element luma balance` therefore
defaults to 0 and should be raised only alongside `Subpixel size`.

Colour alone does not carry it: measured on flat grey, balancing changes the
chroma across a triad not at all (0.343 to 0.345) while more than halving the
brightness variation (0.230 to 0.100). Chroma acuity is roughly a third of
luminance acuity, so at this pitch the eye needs the brightness component.

The tone curve was the other half. Black sat at 0.40 and white at 0.79, so the
whole picture lived in 39% of the range and all of it in the upper half -
which is what "too white" looks like from the front. Black level down to 0.14,
gamma up to 1.35 and brightness up to 2.60 puts black at 0.26 and white at
0.81, spanning 56%. Still a washed-out panel, which an STN is, but no longer
one with everything crushed against the top.

## Diffusion

A photograph of the real panel is soft. The polariser and the front plastic
sit above the cells and spread their light, so edges bleed by about a pixel
and small text half dissolves - on a real Game Gear, "PRESS START" is barely
legible. Sampled sharply the filter reads as a clean grid laid over a clean
picture, which is the one thing the real screen never looks like. This turned
out to be the largest single difference between the filter and a photograph
of the hardware, larger than any amount of tuning the structure.

The three channels also do not share a position. Red's strip sits left of the
cell centre and blue's right of it, about a third of a cell either way, which
is what puts warm and cool fringes on the edges of sprites and text.

Both are one 3x3 read. The channel offset is a sub-pixel shift, so rather than
fetching each channel from its own place - which would triple the reads - it
is folded into the horizontal weights, one set of three per channel over the
same nine taps. Three taps carry a Gaussian this narrow to within about five
percent, and the source texture is 160x144, so all nine fetches come out of
cache. The presets set `wrap_mode` to `clamp_to_edge` because the taps reach
one texel beyond the frame at its border.

Diffusion is deliberately wider across than down. The row gaps are the
structure the eye reads first on the real panel, and blurring vertically as
hard as horizontally dissolves them.

## Subpixels

160x144 at 3x gives three output pixels per cell, which is exactly one per
subpixel, so the stripe can be drawn honestly here - and on a real panel it is
plainly visible, so it is on.

Two details make it read as subpixels rather than as colour fringing. The
channel peaks sit at 1/6, 1/2 and 5/6 of the cell rather than 0, 1/3 and 2/3,
so at an exact 3x a pixel centre lands on each peak and the three pixels of a
cell really are red, green and blue. And the masks are cosines rather than
triangles: three cosines at 120 degrees sum to a constant, so the stripe
shifts colour across the cell without changing how much light leaves it, and
their overlap stands in for the diffuser over a real panel.

A constant sum is not a constant brightness, though, and the difference is
what made the stripe visible as vertical lines. Green carries most of the
luminance and blue almost none, so the raw green band came out 55% brighter
than the blue one. Grey content is where that shows: all three channels are
equal, nothing else in the picture varies, and the ripple is the only
structure left - the instrument panels in G-LOC were the clearest case.
Widening the triad made it worse rather than better, because a six pixel
period is well inside what the eye resolves while a three pixel one is not.

So the stripe is divided by its own luminance before use. The bands then
differ in hue alone, which the eye integrates far more readily - colour acuity
is roughly a third of luminance acuity - and the elements stay just as
colourful: 93% chroma spread within a band, with every band at exactly unit
luminance. On a flat grey patch this takes the column-to-column luminance
swing from 24% to 7%, and what remains is the column gap of the cell grid
rather than the stripe. A real panel is built to look white rather than
banded, so this is also the more faithful behaviour.

The triad can be made wider than one cell with `Subpixel size`. That is not
the way to make the elements read, though - it was tried, and it makes the
picture coarse and unlike the hardware, because the strips stop matching the
panel's real pitch. What makes them read is the black frame around each cell
(`Column gap`) organising them into a grid. `Element gap` will separate the
strips within a triad, but only once a triad is wider than one cell: at the
true pitch an element is exactly one output pixel at 3x and there is no room
inside it for a gap. The phase is quantised to the three
bands of the triad before the cosine is taken, so a triad is always three flat
colours however wide it is - sampling the cosine continuously gives a rainbow
once a triad is more than three pixels across, which is not what a panel looks
like. At one cell on a 3x output the quantisation changes nothing, because the
pixel centres already land on the band centres.

Turn `Subpixel strength` down if the source is being scaled by something other
than an exact 3x, where the phase no longer lines up.

## Parameters

Adjustable from RetroArch's shader parameters menu.

| Parameter | Default | What it does |
|---|---:|---|
| LCD rise speed | 0.62 | how fast a cell brightens; lower smears more |
| LCD fall speed | 0.34 | how fast it darkens; the asymmetry is the trail |
| Diffusion across | 1.00 | how far a cell's light spreads sideways, in source pixels |
| Diffusion down | 0.60 | the same downwards; smaller, so the row lines survive it |
| Element offset | 0.33 | how far red and blue sit either side of the cell centre |
| Subpixel strength | 0.62 | RGB stripe; see above |
| Element luma balance | 0.00 | flattens the stripe's brightness ripple; off at the physical pitch, raise it with `Subpixel size` |
| Subpixel size (cells) | 1 | cells per RGB triad; 1 is the physical layout, larger is easier to see |
| Row gap | 0.80 | the horizontal lines, the dominant structure |
| Column gap | 0.35 | the black frame down the side of each cell |
| Element gap | 0.00 | separation between the strips themselves; needs a triad wider than one cell to do anything |
| Black level | 0.14 | how far the backlight lifts black |
| White level | 0.97 | how far short of white the panel stops |
| Saturation | 0.55 |
| SEGA blue saturation | 0.90 | saturation used only where blue dominates; other hues keep the common saturation |
| Blue-to-green leak | 0.06 | weak green leakage in blue content, without the former red leakage that turned blue grey |
| Panel gamma | 1.35 | |
| Backlight unevenness | 0.28 | falloff away from the lamp |
| Panel cast | 0.55 | the lamp's own colour, a faint green |
| Brightness | 2.60 | backlight saturation constant, not a multiplier |

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
`PLUMOS_GAMEGEAR_LCD_GEOMETRY=integer3x` selects the old 480x432 comparison;
the default `sega43` route is 640x480.

## Verifying it

`scripts/preview-gamegear-lcd.py` reimplements both passes in numpy and writes
before and after images, including a moving block that shows the response
trail. It is how the look was arrived at, and it runs on a build machine.

It does **not** compile the GLSL - there is no validator in the tools image -
so a device run is still what proves the shader loads. If it does not, the
reason will be in RetroArch's log; a GLSL compile failure names the line.
