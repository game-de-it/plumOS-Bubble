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

#pragma parameter gg_subpixel   "Subpixel strength"     0.55 0.00 1.00 0.02
#pragma parameter gg_rowgap     "Row gap"               0.55 0.00 1.00 0.05
#pragma parameter gg_colgap     "Column gap"            0.18 0.00 1.00 0.05
#pragma parameter gg_black      "Black level"           0.10 0.00 0.25 0.005
#pragma parameter gg_white      "White level"           0.90 0.60 1.00 0.01
#pragma parameter gg_sat        "Saturation"            0.82 0.40 1.20 0.02
#pragma parameter gg_gamma      "Panel gamma"           0.90 0.60 1.60 0.02
#pragma parameter gg_backlight  "Backlight unevenness"  0.28 0.00 1.00 0.02
#pragma parameter gg_tint       "Blue cast"             0.55 0.00 1.00 0.05

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
precision mediump float;
#endif

varying vec2 vTex;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform vec2 InputSize;
uniform vec2 OutputSize;

#ifdef PARAMETER_UNIFORM
uniform float gg_subpixel;
uniform float gg_rowgap;
uniform float gg_colgap;
uniform float gg_black;
uniform float gg_white;
uniform float gg_sat;
uniform float gg_gamma;
uniform float gg_backlight;
uniform float gg_tint;
#else
#define gg_subpixel  0.55
#define gg_rowgap    0.55
#define gg_colgap    0.18
#define gg_black     0.10
#define gg_white     0.90
#define gg_sat       0.82
#define gg_gamma     0.90
#define gg_backlight 0.28
#define gg_tint      0.55
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
    * constant: the stripe shifts colour across the cell without also rippling
    * the brightness, its mean is one whatever the strength, and the overlap
    * between neighbours stands in for the diffuser over a real panel.
    *
    * The centres sit at 1/6, 1/2 and 5/6 rather than 0, 1/3 and 2/3 so that at
    * an exact 3x - which is how 160x144 lands on this 640x480 panel - a pixel
    * centre falls on each channel's peak and the three output pixels of a cell
    * really are red, green and blue. */
   const float TAU = 6.2831853;
   vec3 mask = 0.5 + 0.5 * cos(TAU * (phase.x - vec3(1.0, 3.0, 5.0) / 6.0));
   vec3 stripe = mix(vec3(1.0), 2.0 * mask, gg_subpixel);

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
   /* Normalised to unit mean, like the stripe.  Without this the gaps are a
    * brightness cut rather than a structure, and the panel simply goes dark
    * as the grid is turned up.  Over a cell the mean of edge squared is a
    * third, so that is what has to be divided out. */
   float grid = (1.0 - gg_rowgap * edge.y * edge.y - gg_colgap * edge.x * edge.x) /
                (1.0 - (gg_rowgap + gg_colgap) / 3.0);

   /* The Game Gear's cast is not subtle.  Between the CCFL and the STN stack
    * the whole panel sits blue-cyan: light greys come out pale blue and never
    * white, which is the first thing you notice in a photograph of one. */
   vec3 lamp = mix(vec3(1.0), vec3(0.58, 0.84, 1.10), gg_tint);

   vec3 outc = rgb * stripe * grid * lamp * backlight(vTex);
   gl_FragColor = vec4(clamp(outc, 0.0, 1.0), 1.0);
}

#endif
