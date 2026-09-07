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

#pragma parameter gg_subpixel   "Subpixel strength"     0.00 0.00 1.00 0.02
#pragma parameter gg_gap        "Cell gap"              0.35 0.00 1.00 0.05
#pragma parameter gg_black      "Black level"           0.085 0.00 0.25 0.005
#pragma parameter gg_white      "White level"           0.92 0.60 1.00 0.01
#pragma parameter gg_sat        "Saturation"            0.88 0.40 1.20 0.02
#pragma parameter gg_gamma      "Panel gamma"           0.92 0.60 1.60 0.02
#pragma parameter gg_backlight  "Backlight unevenness"  0.28 0.00 1.00 0.02
#pragma parameter gg_tint       "Backlight tint"        0.30 0.00 1.00 0.05

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
uniform float gg_gap;
uniform float gg_black;
uniform float gg_white;
uniform float gg_sat;
uniform float gg_gamma;
uniform float gg_backlight;
uniform float gg_tint;
#else
#define gg_subpixel  0.00
#define gg_gap       0.35
#define gg_black     0.085
#define gg_white     0.92
#define gg_sat       0.88
#define gg_gamma     0.92
#define gg_backlight 0.28
#define gg_tint      0.30
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
    * constant: the stripe then shifts colour across the cell without also
    * rippling the brightness, and its mean is one whatever the strength. */
   const float TAU = 6.2831853;
   vec3 mask = 0.5 + 0.5 * cos(TAU * (phase.x - vec3(0.0, 1.0, 2.0) / 3.0));
   vec3 stripe = mix(vec3(1.0), 2.0 * mask, gg_subpixel);

   /* Cell structure.  A hard border does not survive this scale: at an exact
    * 3x a cell is three pixels, so pixel centres only ever land at 1/6, 1/2
    * and 5/6 of it and a narrow edge band is never sampled at all.  This is a
    * smooth falloff from the centre of the cell instead, which is closer to
    * how a real cell looks anyway and still reads as a grid at 3x. */
   vec2 edge = abs(phase - 0.5) * 2.0;
   float grid = 1.0 - gg_gap * 0.5 * dot(edge, edge);

   /* The backlight is not white; it pushes the panel slightly green-blue. */
   vec3 lamp = mix(vec3(1.0), vec3(0.94, 1.0, 0.99), gg_tint);

   vec3 outc = rgb * stripe * grid * lamp * backlight(vTex);
   gl_FragColor = vec4(clamp(outc, 0.0, 1.0), 1.0);
}

#endif
