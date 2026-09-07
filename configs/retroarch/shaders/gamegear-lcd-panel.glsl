/*
 * Game Gear LCD, pass 2: the panel itself.
 *
 * Four things separate this screen from a generic LCD filter:
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
 */

#pragma parameter gg_subpixel   "Subpixel strength"     0.62 0.00 1.00 0.02
#pragma parameter gg_subcells   "Subpixel size (cells)" 2.00 1.00 4.00 1.00
#pragma parameter gg_rowgap     "Row gap"               0.55 0.00 1.00 0.05
#pragma parameter gg_colgap     "Column gap"            0.18 0.00 1.00 0.05
#pragma parameter gg_black      "Black level"           0.17 0.00 0.35 0.005
#pragma parameter gg_white      "White level"           0.97 0.60 1.10 0.01
#pragma parameter gg_sat        "Saturation"            0.82 0.40 1.20 0.02
#pragma parameter gg_gamma      "Panel gamma"           0.90 0.60 1.60 0.02
#pragma parameter gg_backlight  "Backlight unevenness"  0.28 0.00 1.00 0.02
#pragma parameter gg_tint       "Blue cast"             0.55 0.00 1.00 0.05
#pragma parameter gg_bright     "Brightness"            2.30 0.50 5.00 0.05

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
uniform float gg_subpixel;
uniform float gg_subcells;
uniform float gg_rowgap;
uniform float gg_colgap;
uniform float gg_black;
uniform float gg_white;
uniform float gg_sat;
uniform float gg_gamma;
uniform float gg_backlight;
uniform float gg_tint;
uniform float gg_bright;
#else
#define gg_subpixel  0.62
#define gg_subcells  2.00
#define gg_rowgap    0.55
#define gg_colgap    0.18
#define gg_black     0.17
#define gg_white     0.97
#define gg_sat       0.82
#define gg_gamma     0.90
#define gg_backlight 0.28
#define gg_tint      0.55
#define gg_bright    2.30
#endif

/* The lamp sat along one edge, so the light falls away from it and the far
 * corners are dimmest.  Kept gentle: the point is that it is never flat. */
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

   vec3 rgb = texture2D(Texture, vTex).rgb;

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
    * Equalise the bands' luminance.
    *
    * Green carries most of the luminance and blue almost none, so a plain
    * stripe makes the green band far brighter than the blue one - 55% apart
    * at this strength.  On grey content, where all three channels are equal
    * and nothing else varies, that ripple is the only structure present and
    * it reads as vertical lines: worst on the instrument panels of a game
    * like G-LOC.  Widening the triad made it worse rather than better,
    * because a six pixel period is well inside what the eye resolves while a
    * three pixel one is not.
    *
    * Dividing the luminance out leaves the bands differing in hue alone,
    * which the eye integrates far more readily - its colour acuity is about a
    * third of its luminance acuity.  A real panel is built to look white
    * rather than banded, so this is also the honest behaviour.
    */
   stripe /= dot(stripe, vec3(0.299, 0.587, 0.114));

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
