/*
 * Game Gear LCD, pass 2: the panel itself.
 *
 * Six things separate this screen from a generic LCD filter:
 *
 *   - RGB stripe subpixels.  The Game Gear's cells are large enough that at
 *     any honest magnification you see the three vertical strips, not a solid
 *     colour.  The phase is taken from the source pixel, so this works at any
 *     scale; at an exact 3x it lands one strip per output pixel.
 *   - The gap between cells, which is what makes it read as a grid rather
 *     than as scanlines.  It is a grid, not lines: this is not a CRT.
 *   - An STN gamut.  Black is a dark grey lit from behind, saturation is low,
 *     and the top end compresses rather than clipping.
 *   - A CCFL edge light.  It is brighter near the lamp and falls away across
 *     the panel, which is why a real Game Gear photograph is never evenly lit.
 *   - Diffusion.  A photograph of the real panel is soft: the polariser and
 *     the front plastic spread each cell's light into its neighbours, so
 *     edges bleed and small text half dissolves.  Without this the filter
 *     looks like a clean grid laid over a sharp picture, which is the one
 *     thing a real Game Gear never looks like.
 *   - Element offset.  Each channel is read from where its own strip
 *     physically sits - red left of the cell centre, blue right of it - so
 *     edges pick up the colour fringes a real panel shows.
 */

#pragma parameter gg_bleed_x    "Diffusion across"      1.00 0.00 1.50 0.05
#pragma parameter gg_bleed_y    "Diffusion down"        0.60 0.00 1.50 0.05
#pragma parameter gg_fringe     "Element offset"        0.33 0.00 0.60 0.03
#pragma parameter gg_subpixel   "Subpixel strength"     0.62 0.00 1.00 0.02
#pragma parameter gg_balance    "Element luma balance"  0.00 0.00 1.00 0.05
#pragma parameter gg_subcells   "Subpixel size (cells)" 1.00 1.00 4.00 1.00
#pragma parameter gg_rowgap     "Row gap"               0.80 0.00 1.00 0.05
#pragma parameter gg_colgap     "Column gap"            0.35 0.00 1.00 0.05
#pragma parameter gg_elemgap    "Element gap"           0.00 0.00 1.00 0.05
#pragma parameter gg_black      "Black level"           0.14 0.00 0.40 0.005
#pragma parameter gg_white      "White level"           0.97 0.60 1.10 0.01
#pragma parameter gg_sat        "Saturation"            0.55 0.20 1.20 0.02
#pragma parameter gg_gamma      "Panel gamma"           1.35 0.60 2.20 0.05
#pragma parameter gg_backlight  "Backlight unevenness"  0.28 0.00 1.00 0.02
#pragma parameter gg_tint       "Blue cast"             0.55 0.00 1.00 0.05
#pragma parameter gg_bright     "Brightness"            2.60 0.50 5.00 0.05

#if defined(VERTEX)

attribute vec4 VertexCoord;
attribute vec4 TexCoord;
varying vec2 vTex;
uniform mat4 MVPMatrix;

void main(void) {
   gl_Position = MVPMatrix * VertexCoord;
   vTex = TexCoord.xy;
}

#elif defined(FRAGMENT)

#ifdef GL_ES
/* The cell phase comes from a source pixel index, which reaches 160 here.  In
 * mediump that value has a resolution of about an eighth, so fract() of it
 * would quantise the phase and band the stripe.  Ask for highp where the
 * implementation has it. */
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
#endif

varying vec2 vTex;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform vec2 InputSize;
uniform vec2 OutputSize;

#ifdef PARAMETER_UNIFORM
uniform float gg_bleed_x;
uniform float gg_bleed_y;
uniform float gg_fringe;
uniform float gg_subpixel;
uniform float gg_balance;
uniform float gg_subcells;
uniform float gg_rowgap;
uniform float gg_colgap;
uniform float gg_elemgap;
uniform float gg_black;
uniform float gg_white;
uniform float gg_sat;
uniform float gg_gamma;
uniform float gg_backlight;
uniform float gg_tint;
uniform float gg_bright;
#else
#define gg_bleed_x   1.00
#define gg_bleed_y   0.60
#define gg_fringe    0.33
#define gg_subpixel  0.62
#define gg_balance   0.00
#define gg_subcells  1.00
#define gg_rowgap    0.80
#define gg_colgap    0.35
#define gg_elemgap   0.00
#define gg_black     0.14
#define gg_white     0.97
#define gg_sat       0.55
#define gg_gamma     1.35
#define gg_backlight 0.28
#define gg_tint      0.55
#define gg_bright    2.60
#endif

/* The lamp sat along one edge, so the light falls away from it and the far
 * corners are dimmest.  Kept gentle: the point is that it is never flat. */
/* Three tap weights at -1, 0 and +1 source pixels, for a Gaussian of width
 * `sigma` whose centre has been moved to `shift`.  Three taps carry a narrow
 * Gaussian well enough - at sigma 0.6 the tails outside them are about five
 * percent - and three is what keeps the whole thing to nine fetches. */
vec3 taps(float sigma, float shift) {
   vec3 d = vec3(-1.0, 0.0, 1.0) - vec3(shift);
   vec3 w = exp(-0.5 * d * d / max(sigma * sigma, 1e-4));
   return w / max(w.x + w.y + w.z, 1e-6);
}

float backlight(vec2 uv) {
   vec2 c = uv - vec2(0.5, 0.42);
   float radial = 1.0 - dot(c, c) * 0.85;
   float edge = 1.0 - 0.18 * uv.y;
   return mix(1.0, radial * edge, gg_backlight);
}

void main(void) {
   /* Position inside the source pixel drives both the stripe and the gap. */
   vec2 cell = vTex * TextureSize;
   vec2 phase = fract(cell);

   /*
    * Diffusion, and the offset between the three elements, in one 3x3 read.
    *
    * A photograph of the real panel is soft.  The polariser and the front
    * plastic sit above the cells and spread their light, so edges bleed by
    * about a pixel and small text half dissolves.  Sampled sharply the filter
    * reads as a clean grid over a clean picture, which is the one thing the
    * real screen never looks like.
    *
    * The channels also do not share a position: red's strip sits left of the
    * cell centre and blue's right of it, roughly a third of a cell either
    * way, which is what puts warm and cool fringes on the edges of sprites
    * and text.  That is a sub-pixel shift, so rather than fetching each
    * channel from its own place - which would triple the reads - it is folded
    * into the horizontal weights, one set per channel over the same taps.
    *
    * Nine fetches, from a 160x144 texture that stays entirely in cache.
    */
   vec2 texel = 1.0 / TextureSize;
   vec3 wxr = taps(gg_bleed_x, -gg_fringe);
   vec3 wxg = taps(gg_bleed_x,  0.0);
   vec3 wxb = taps(gg_bleed_x,  gg_fringe);
   vec3 wy  = taps(gg_bleed_y,  0.0);

   /* One column of horizontal weights, one entry per channel. */
   vec3 cl = vec3(wxr.x, wxg.x, wxb.x);
   vec3 cc = vec3(wxr.y, wxg.y, wxb.y);
   vec3 cr = vec3(wxr.z, wxg.z, wxb.z);

   /* Unrolled rather than looped: the weights differ per channel and per tap,
    * and picking them out inside a loop needs either dynamic indexing, which
    * GLSL ES 1.00 does not promise, or a chain of comparisons that costs more
    * than the nine lines it saves. */
   vec3 rgb =
      (texture2D(Texture, vTex + vec2(-texel.x, -texel.y)).rgb * cl +
       texture2D(Texture, vTex + vec2(     0.0, -texel.y)).rgb * cc +
       texture2D(Texture, vTex + vec2( texel.x, -texel.y)).rgb * cr) * wy.x +
      (texture2D(Texture, vTex + vec2(-texel.x,      0.0)).rgb * cl +
       texture2D(Texture, vTex                                ).rgb * cc +
       texture2D(Texture, vTex + vec2( texel.x,      0.0)).rgb * cr) * wy.y +
      (texture2D(Texture, vTex + vec2(-texel.x,  texel.y)).rgb * cl +
       texture2D(Texture, vTex + vec2(     0.0,  texel.y)).rgb * cc +
       texture2D(Texture, vTex + vec2( texel.x,  texel.y)).rgb * cr) * wy.z;

   /* STN gamut.  The panel is washed out rather than dark: the floor lifts
    * because the backlight leaks through, and the ceiling never reaches white.
    * That is a contrast range, not a gamma curve, so it is applied as one. */
   float luma = dot(rgb, vec3(0.299, 0.587, 0.114));
   rgb = mix(vec3(luma), rgb, gg_sat);
   rgb = pow(clamp(rgb, 0.0, 1.0), vec3(gg_gamma));
   rgb = gg_black + rgb * (gg_white - gg_black);

   /* RGB stripe, as three cosines a third of a cell apart.  Cosines rather
    * than the obvious triangles because three of them at 120 degrees sum to a
    * constant, so the stripe shifts colour across the cell without changing
    * how much light leaves it, and the overlap between neighbours stands in
    * for the diffuser over a real panel.  A constant sum is not the same as a
    * constant brightness, though - see the balancing step below.
    *
    * The centres sit at 1/6, 1/2 and 5/6 rather than 0, 1/3 and 2/3 so that at
    * an exact 3x - which is how 160x144 lands on this 640x480 panel - a pixel
    * centre falls on each channel's peak and the three output pixels of a cell
    * really are red, green and blue. */
   const float TAU = 6.2831853;
   /* One triad every gg_subcells cells.  At one it is the physical layout;
    * larger makes the elements bigger and easier to see, at the cost of no
    * longer matching the panel one to one.  A whole number of cells keeps the
    * stripe in step with the grid - a fractional one would beat against it. */
   float sub_phase = fract(cell.x / gg_subcells);
   /* Quantised to the three bands of the triad before the cosine is taken, so
    * a triad is always three flat colours however wide it is.  Sampling the
    * cosine continuously instead gave a rainbow once a triad was more than
    * three pixels across, which is not what a panel looks like.  At one cell
    * on a 3x output this is identical to sampling it directly, because the
    * pixel centres already land on the band centres. */
   float band = (floor(sub_phase * 3.0) + 0.5) / 3.0;
   vec3 mask = 0.5 + 0.5 * cos(TAU * (band - vec3(1.0, 3.0, 5.0) / 6.0));
   vec3 stripe = mix(vec3(1.0), 2.0 * mask, gg_subpixel);
   /*
    * Optionally equalise the bands' luminance.
    *
    * Green carries most of the luminance and blue almost none, so the raw
    * stripe makes the green band brighter than the blue one - 55% apart at
    * this strength.  Dividing that out leaves the bands differing in hue
    * alone, which the eye integrates far more readily, since its colour
    * acuity is about a third of its luminance acuity.
    *
    * Which is exactly why this is off by default.  At one cell per triad an
    * element is one output pixel at 3x, so the imbalance is a three pixel
    * ripple - below what the eye separates into lines, and the only thing
    * that makes the elements visible at all rather than a flat wash.
    * Balancing it away here left the panel looking like plain blurred pixels
    * on the device.
    *
    * Turn it up when the triad is widened past one cell.  There the ripple
    * lands at six pixels or more, which the eye does resolve, and it reads as
    * vertical banding on grey - worst on something like G-LOC's instruments.
    */
   stripe = mix(stripe, stripe / dot(stripe, vec3(0.299, 0.587, 0.114)),
                gg_balance);

   /* An optional dark line between the elements themselves rather than
    * between cells.  It does nothing at one cell per triad, where an element
    * is exactly one output pixel at 3x and there is no room inside it for a
    * gap - widen the triad first, and this is what then separates the strips.
    * Left off by default: the column gap below already reads as the black
    * frame around each cell, and at the panel's true element pitch that is
    * the only separation the eye can actually resolve. */
   if (gg_elemgap > 0.001) {
      float ep = abs(fract(cell.x * 3.0 / gg_subcells) - 0.5) * 2.0;
      stripe *= (1.0 - gg_elemgap * ep * ep) / (1.0 - gg_elemgap / 3.0);
   }

   /* Cell structure.  A hard border does not survive this scale: at an exact
    * 3x a cell is three pixels, so pixel centres only ever land at 1/6, 1/2
    * and 5/6 of it and a narrow edge band is never sampled at all.  This is a
    * smooth falloff from the centre of the cell instead, which is closer to
    * how a real cell looks anyway and still reads as a grid at 3x. */
   vec2 edge = abs(phase - 0.5) * 2.0;
   /* The row gap dominates.  On a real panel the gap between rows is a whole
    * cell boundary while the columns are split by subpixels, so the screen
    * reads as fine horizontal lines with colour texture between them - which
    * is what a photograph of one shows. */
   /* The grid carries unit mean and the stripe unit luminance, so structure
    * costs contrast rather than light.  That does push peaks above one, which
    * the saturation below absorbs - clipping them instead would flatten the
    * highlights and cost them their blue cast. */
   float grid = (1.0 - gg_rowgap * edge.y * edge.y - gg_colgap * edge.x * edge.x) /
                (1.0 - (gg_rowgap + gg_colgap) / 3.0);

   /* The Game Gear's cast is not subtle.  Between the CCFL and the STN stack
    * the whole panel sits blue-cyan: light greys come out pale blue and never
    * white, which is the first thing you notice in a photograph of one. */
   vec3 lamp = mix(vec3(1.0), vec3(0.53, 0.76, 1.00), gg_tint);

   vec3 outc = rgb * stripe * grid * lamp * backlight(vTex);

   /* Backlight saturation.  A cell cannot pass more light than there is
    * behind it, so the response rolls off rather than clipping: this lifts the
    * average, which is what looked dark, while the peaks the structure creates
    * approach one instead of being cut flat there. */
   outc = 1.0 - exp(-gg_bright * max(outc, vec3(0.0)));

   gl_FragColor = vec4(clamp(outc, 0.0, 1.0), 1.0);
}

#endif
