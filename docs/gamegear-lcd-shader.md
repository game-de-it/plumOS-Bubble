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

**The blue cast, which is not subtle.** Between the CCFL and the STN stack the
whole panel sits blue-cyan: light greys come out pale blue and never white.
It is the first thing you notice in a photograph of a real Game Gear, and
leaving it out is what makes an LCD filter look generic. A source white ends
up around R:G:B of 1 : 1.1 : 1.3.

**Backlight.** The CCFL sat along one edge, so the light falls away from it
and the far corners are dimmest. A real Game Gear photograph is never evenly
lit. Kept gentle - the point is only that it is not flat.

## Scaling: the picture must be an exact 3x

This is a requirement, not a preference. The panel pass takes the phase of its
cell grid and its RGB stripe from the source pixel, so it is only correct when
a source pixel covers a whole number of output pixels.

160x144 into 640x480 is 4.00x across but 3.33x down, so the largest integer
that fits both axes is three: 480x432, centred, leaving an 80px border either
side and 24px above and below. `plumos-retroarch-launch` pins that with a
custom viewport for the Game Gear launch only.

Letting RetroArch fit the picture instead is visibly wrong rather than subtly
so. On a flat grey field, measured through the reference implementation:

| Output | Scale | Column swing | Row swing | Mean R:G:B |
|---|---|---:|---:|---|
| 640x480 | 4.00x / 3.33x | 21% | 128% | 0.82 : 1.00 : 0.95 |
| 576x432 | 3.60x / 3.00x | 38% | 34% | 0.92 : 1.00 : 1.05 |
| 533x480 | 3.33x / 3.33x | 53% | 139% | 0.92 : 1.00 : 1.04 |
| **480x432** | **3.00x / 3.00x** | **15%** | **33%** | 0.92 : 1.00 : 1.05 |

At an exact 3x the remaining swing is the intended structure, regular and at a
three pixel period. Off it, the row gaps beat against the output grid and
march up the screen at more than four times that amplitude. At 640x480 the
stripe must also fit three elements into four pixels, which cannot be done
evenly: red comes out 18% low and tints the whole picture.

A custom viewport rather than square-pixel aspect plus integer scaling,
because this panel is 640x480 and nothing else, so an exact rectangle is worth
more here than portability - and it depends on neither what the core reports
for its aspect ratio nor on how RetroArch rounds. A port to a different
display should work out its own largest integer scale rather than reuse these
numbers.

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
| Subpixel size (cells) | 1 | cells per RGB triad; 1 is the physical layout, larger is easier to see |
| Row gap | 0.80 | the horizontal lines, the dominant structure |
| Column gap | 0.35 | the black frame down the side of each cell |
| Element gap | 0.00 | separation between the strips themselves; needs a triad wider than one cell to do anything |
| Black level | 0.28 | how far the backlight lifts black |
| White level | 0.97 | how far short of white the panel stops |
| Saturation | 0.60 | |
| Panel gamma | 0.90 | |
| Backlight unevenness | 0.28 | falloff away from the lamp |
| Blue cast | 0.55 | how far towards blue-cyan the panel sits |
| Brightness | 2.30 | backlight saturation constant, not a multiplier |

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
