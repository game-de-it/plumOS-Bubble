/*
 * Game Gear LCD, pass 2: the panel itself.
 *
 * Six things separate this screen from a generic LCD filter:
 *
 *   - RGB stripe subpixels.  The Game Gear's cells are large enough that at
 *     any honest magnification you see the three vertical strips, not a solid
 *     colour.  The phase is taken from the source pixel.  When a strip does
 *     not land on a whole output pixel, its area is integrated over that
 *     output pixel so no channel wins merely because of the sampling phase.
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

#pragma parameter gg_bleed_x    "Colour bleed across"   0.85 0.00 1.50 0.05
#pragma parameter gg_bleed_y    "Colour bleed down"     0.45 0.00 1.50 0.05
#pragma parameter gg_fringe     "Element offset"        0.25 0.00 0.60 0.03
#pragma parameter gg_lumableed  "Luma bleed"            0.18 0.00 1.00 0.02
#pragma parameter gg_smear_up   "Upward colour trail"   0.18 0.00 0.60 0.02
#pragma parameter gg_smear_luma "Centre bright invasion" 1.00 0.00 1.00 0.05
#pragma parameter gg_center_dark "Centre dark invasion"   0.20 0.00 1.00 0.05
#pragma parameter gg_dark_smear "Edge dark invasion"     0.75 0.00 1.00 0.05
#pragma parameter gg_subpixel   "Subpixel strength"     0.62 0.00 1.00 0.02
#pragma parameter gg_aperture   "4:3 aperture gap"      0.88 0.00 1.00 0.02
#pragma parameter gg_balance    "Element luma balance"  0.00 0.00 1.00 0.05
#pragma parameter gg_subcells   "Subpixel size (cells)" 1.00 1.00 4.00 1.00
#pragma parameter gg_rowgap     "Row gap"               0.80 0.00 1.00 0.05
#pragma parameter gg_colgap     "Column gap"            0.35 0.00 1.00 0.05
#pragma parameter gg_elemgap    "Element gap"           0.35 0.00 1.00 0.05
#pragma parameter gg_black      "Black level"           0.14 0.00 0.40 0.005
#pragma parameter gg_white      "White level"           0.97 0.60 1.10 0.01
#pragma parameter gg_sat        "Saturation"            0.55 0.20 1.20 0.02
#pragma parameter gg_bluesat    "SEGA blue saturation"  0.90 0.20 1.20 0.02
#pragma parameter gg_blueweak   "Blue-to-green leak"    0.14 0.00 0.80 0.02
#pragma parameter gg_gamma      "Panel gamma"           1.35 0.60 2.20 0.05
#pragma parameter gg_backlight  "Backlight unevenness"  0.28 0.00 1.00 0.02
#pragma parameter gg_tint       "Panel cast"            0.55 0.00 1.00 0.05
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
uniform float gg_lumableed;
uniform float gg_smear_up;
uniform float gg_smear_luma;
uniform float gg_center_dark;
uniform float gg_dark_smear;
uniform float gg_subpixel;
uniform float gg_aperture;
uniform float gg_balance;
uniform float gg_subcells;
uniform float gg_rowgap;
uniform float gg_colgap;
uniform float gg_elemgap;
uniform float gg_black;
uniform float gg_white;
uniform float gg_sat;
uniform float gg_bluesat;
uniform float gg_blueweak;
uniform float gg_gamma;
uniform float gg_backlight;
uniform float gg_tint;
uniform float gg_bright;
#else
#define gg_bleed_x   0.85
#define gg_bleed_y   0.45
#define gg_fringe    0.25
#define gg_lumableed 0.18
#define gg_smear_up  0.18
#define gg_smear_luma 1.00
#define gg_center_dark 0.20
#define gg_dark_smear 0.75
#define gg_subpixel  0.62
#define gg_aperture  0.88
#define gg_balance   0.00
#define gg_subcells  1.00
#define gg_rowgap    0.80
#define gg_colgap    0.35
#define gg_elemgap   0.35
#define gg_black     0.14
#define gg_white     0.97
#define gg_sat       0.55
#define gg_bluesat   0.90
#define gg_blueweak  0.14
#define gg_gamma     1.35
#define gg_backlight 0.28
#define gg_tint      0.55
#define gg_bright    2.60
#endif

/* Three tap weights at -1, 0 and +1 source pixels, for a Gaussian of width
 * `sigma` whose centre has been moved to `shift`.  Three taps carry a narrow
 * Gaussian well enough - at sigma 0.6 the tails outside them are about five
 * percent - and three is what keeps the whole thing to nine fetches. */
vec3 taps(float sigma, float shift) {
   vec3 d = vec3(-1.0, 0.0, 1.0) - vec3(shift);
   vec3 w = exp(-0.5 * d * d / max(sigma * sigma, 1e-4));
   return w / max(w.x + w.y + w.z, 1e-6);
}

/* The original lamp is a horizontal CCFL tube behind a reflector, not a
 * point source.  Distance to a horizontal line segment gives a capsule-shaped
 * field: uniform along most of the tube, smoothly rounded only beyond its
 * ends.  This avoids the false concentric rings produced by a radial field.
 * X is converted to physical viewport distance because the Game Gear's
 * logical pixels are stretched to a 4:3 aperture on Bubble. */
float horizontal_tube_distance(vec2 uv) {
   vec2 p = uv - vec2(0.5);
   float beyond_end = max(abs(p.x) - 0.38, 0.0);
   beyond_end *= OutputSize.x / OutputSize.y;
   return length(vec2(beyond_end, p.y));
}

float tube_edge_response(vec2 uv) {
   return smoothstep(0.0, 0.56, horizontal_tube_distance(uv));
}

float backlight(vec2 uv) {
   float away_from_tube = tube_edge_response(uv);
   /* Preserve the previous model's measured output range (about 0.84..0.98
    * after gg_backlight=0.28), so this changes the field's shape rather than
    * silently making the entire panel brighter. */
   float tube_light = 0.936 - 0.522 * away_from_tube;
   return mix(1.0, tube_light, gg_backlight);
}

/* Analytic coverage avoids derivative instructions, which GLSL ES 1.00 does
 * not guarantee on this hardware. */
float periodic_box_integral(float x, float a, float b) {
   float whole = floor(x);
   return whole * (b - a) + clamp(fract(x) - a, 0.0, b - a);
}

float periodic_box_coverage(float centre, float width, float a, float b) {
   float half_width = 0.5 * width;
   return (periodic_box_integral(centre + half_width, a, b) -
           periodic_box_integral(centre - half_width, a, b)) /
          max(width, 1e-6);
}

/* Integral of (2*abs(fract(x)-0.5))^2. */
float edge2_integral(float x) {
   float whole = floor(x);
   float p = fract(x) - 0.5;
   return whole / 3.0 + (4.0 / 3.0) * p * p * p + 1.0 / 6.0;
}

float edge2_coverage(float centre, float width) {
   float half_width = 0.5 * width;
   return (edge2_integral(centre + half_width) -
           edge2_integral(centre - half_width)) / max(width, 1e-6);
}

void main(void) {
   /* TextureSize is the backing FBO (256x256 on Bubble), while InputSize is
    * the valid Game Gear picture (160x144).  `cell` deliberately uses the
    * former because vTex addresses that backing texture; content_uv and every
    * scale calculation must use the latter or the image centre is mistaken
    * for the lower-right edge. */
   vec2 cell = vTex * TextureSize;
   vec2 content_uv = cell / InputSize;
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
   vec3 wy  = taps(gg_bleed_y,  gg_smear_up);

   /* One column of horizontal weights, one entry per channel. */
   vec3 cl = vec3(wxr.x, wxg.x, wxb.x);
   vec3 cc = vec3(wxr.y, wxg.y, wxb.y);
   vec3 cr = vec3(wxr.z, wxg.z, wxb.z);

   /* Unrolled rather than looped: the weights differ per channel and per tap,
    * and picking them out inside a loop needs either dynamic indexing, which
    * GLSL ES 1.00 does not promise, or a chain of comparisons that costs more
    * than the nine lines it saves. */
   vec3 diffused =
      (texture2D(Texture, vTex + vec2(-texel.x, -texel.y)).rgb * cl +
       texture2D(Texture, vTex + vec2(     0.0, -texel.y)).rgb * cc +
       texture2D(Texture, vTex + vec2( texel.x, -texel.y)).rgb * cr) * wy.x +
      (texture2D(Texture, vTex + vec2(-texel.x,      0.0)).rgb * cl +
       texture2D(Texture, vTex                                ).rgb * cc +
       texture2D(Texture, vTex + vec2( texel.x,      0.0)).rgb * cr) * wy.y +
      (texture2D(Texture, vTex + vec2(-texel.x,  texel.y)).rgb * cl +
       texture2D(Texture, vTex + vec2(     0.0,  texel.y)).rgb * cc +
       texture2D(Texture, vTex + vec2( texel.x,  texel.y)).rgb * cr) * wy.z;

   /* A uniform RGB blur destroyed the tiny lettering.  The old panel looks
    * out of focus mainly because colour crosses cell boundaries while the
    * black matrix and dark one-dot shadows still define a luminance edge.
    * Keep most luma from the centre texel, take chroma from the diffused
    * sample, and admit only a small amount of diffused luma. */
   const vec3 PANEL_LUMA = vec3(0.299, 0.587, 0.114);
   vec3 centre_rgb = texture2D(Texture, vTex).rgb;
   float centre_luma = dot(centre_rgb, PANEL_LUMA);
   float diffused_luma = dot(diffused, PANEL_LUMA);
   float preserved_luma = mix(centre_luma, diffused_luma, gg_lumableed);
   /* Both reference panels carry the same one-source-row echo above bright
    * detail.  Keep it directional: copying the row below upward joins the
    * bars of one-dot lettering without applying a uniform soft-focus pass. */
   vec3 rgb = diffused + vec3(preserved_luma - diffused_luma);
   /* OpenGL texture Y grows upward, unlike the top-down numpy preview.  The
    * row visually below this one is therefore -texel.y; using +texel.y copied
    * the upper source row downward on the device. */
   vec3 lower_rgb = texture2D(Texture,
                              vTex - vec2(0.0, texel.y)).rgb;
   /* Copy the source colour, not a neutral luminance echo.  Sonic 2's tiny
    * footer glyphs intentionally mix white with two lavender palette steps;
    * preserving those channel ratios is what lets the panel turn different
    * letters into different-looking broken strokes. */
   float current_row_luma = dot(rgb, PANEL_LUMA);
   float lower_row_luma = dot(lower_rgb, PANEL_LUMA);
   /* The photographed centre and footer cannot be matched by one global
    * direction of row crosstalk.  Around the backlight's broad central field,
    * lifted blacks and strong whites let either neighbour take over by the
    * same response model used by the accepted upward-ghost preview.  Bright
    * takeover is 100%, while dark takeover is held to 20%; increasing both
    * together made the dark row below the tiny E win instead.
    * Toward the panel
    * edge, weak whites cease to invade while the denser dark state rises to
    * 75% toward the outer edge, retaining the broken footer strokes without
    * making the centre-to-edge weight change conspicuous in text-heavy games.
    * This is a continuous optical/electrical field, not a title- or
    * glyph-specific exception. */
   /* Use the same horizontal-tube field for STN row response and illumination.
    * A point-source radius made one-dot text cross visible circular response
    * bands.  Distance from a line segment changes mainly from top to bottom,
    * with only a smooth end falloff at the far left and right. */
   float edge_response = tube_edge_response(content_uv);
   float bright_row_mix = gg_smear_luma * (1.0 - edge_response);
   float dark_row_mix = mix(gg_center_dark, gg_dark_smear, edge_response);
   float row_mix = mix(bright_row_mix, dark_row_mix,
                       step(lower_row_luma, current_row_luma));
   rgb = mix(rgb, lower_rgb, row_mix);

   /*
    * The blue filter is the weakest layer on an STN panel.  It separates blue
    * from the rest of the backlight poorly, so blue content arrives with its
    * colour washed out - but not its brightness, which is why this puts the
    * light back rather than simply desaturating.
    *
    * Measured against a photograph of the hardware showing Sonic 2's title:
    * the background, a pure blue in the ROM, comes off the real panel at a
    * chroma of 0.15 - all but neutral - while the red of the banner keeps
    * 0.60.  A global saturation cannot do that; it would take the banner down
    * with the background.  Nor can a model that adds light for blue: matching
    * the background's chroma that way lifts it to within 1.5x of white, and
    * on the real screen "PRESS START BUTTON" stays legible against it.
    * Preserving the luminance satisfies both at once - chroma 0.16 against
    * the measured 0.15, brightness 0.32 against 0.35.
    */
   if (gg_blueweak > 0.001) {
      const vec3 LUMA = vec3(0.299, 0.587, 0.114);
      float before = dot(rgb, LUMA);
      /* The SEGA panel photograph shows blue leaking mainly toward green,
       * not equally into red and green.  That keeps the characteristic cyan
       * blue instead of turning it into neutral grey. */
      vec3 washed = rgb + gg_blueweak * rgb.b * vec3(0.0, 1.00, 0.0);
      rgb = washed * (before / max(dot(washed, LUMA), 1e-5));
   }

   /* STN gamut.  The panel is washed out rather than dark: the floor lifts
    * because the backlight leaks through, and the ceiling never reaches white.
    * That is a contrast range, not a gamma curve, so it is applied as one. */
   float luma = dot(rgb, vec3(0.299, 0.587, 0.114));
   float blue_dominance =
      clamp((rgb.b - max(rgb.r, rgb.g)) / max(rgb.b, 1e-5), 0.0, 1.0);
   float panel_sat = mix(gg_sat, gg_bluesat, blue_dominance);
   rgb = mix(vec3(luma), rgb, panel_sat);
   rgb = pow(clamp(rgb, 0.0, 1.0), vec3(gg_gamma));
   /* The blue cell blocks considerably more red backlight than the old
    * all-grey floor model allowed.  Keep the common floor for neutral and
    * warm colours, but lower only its red component in blue-dominant areas. */
   vec3 black_floor = gg_black *
      vec3(mix(1.0, 0.55, blue_dominance), 1.0, 1.0);
   rgb = black_floor + rgb * (gg_white - black_floor);

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
   float sub_coord = cell.x / gg_subcells;
   float sub_phase = fract(sub_coord);
   /* Quantised to the three bands of the triad before the cosine is taken, so
    * a triad is always three flat colours however wide it is.  Sampling the
    * cosine continuously instead gave a rainbow once a triad was more than
    * three pixels across, which is not what a panel looks like.  At one cell
    * on a 3x output this is identical to sampling it directly, because the
    * pixel centres already land on the band centres. */
   float band = (floor(sub_phase * 3.0) + 0.5) / 3.0;
   vec3 mask = 0.5 + 0.5 * cos(TAU * (band - vec3(1.0, 3.0, 5.0) / 6.0));
   vec3 stripe_point = mix(vec3(1.0), 2.0 * mask, gg_subpixel);

   /* At 4:3 one source cell is four output pixels wide, so each of its three
    * elements is 4/3 pixels wide.  Centre sampling would favour one channel.
    * Average the three flat bands over the output-pixel footprint instead.
    * Exact 3x/6x paths retain their one-/two-pixel-per-element rendering. */
   float sub_width = (InputSize.x / OutputSize.x) / gg_subcells;
   float cov_r = periodic_box_coverage(sub_coord, sub_width, 0.0, 1.0 / 3.0);
   float cov_g = periodic_box_coverage(sub_coord, sub_width, 1.0 / 3.0, 2.0 / 3.0);
   float cov_b = periodic_box_coverage(sub_coord, sub_width, 2.0 / 3.0, 1.0);
   vec3 integrated_mask =
      cov_r * vec3(2.0, 0.5, 0.5) +
      cov_g * vec3(0.5, 2.0, 0.5) +
      cov_b * vec3(0.5, 0.5, 2.0);
   vec3 stripe_integrated = mix(vec3(1.0), integrated_mask, gg_subpixel);
   float element_pixels = (OutputSize.x / InputSize.x) * gg_subcells / 3.0;
   float element_misalignment =
      step(0.001, abs(element_pixels - floor(element_pixels + 0.5)));
   vec3 stripe = mix(stripe_point, stripe_integrated, element_misalignment);

   /* The 4:3 SEGA aperture gives exactly four output pixels to one source
    * cell on Bubble.  The hardware close-up shows three colour apertures and
    * a conspicuously dark boundary, rather than four blended colour samples.
    * Model that as R/G/B/gap.  The gap is kept separate from subpixel colour
    * strength because it is an aperture/black-matrix property. */
   float scale_x = OutputSize.x / InputSize.x;
   float four_pixel_cell =
      (1.0 - step(0.001, abs(scale_x - 4.0))) *
      (1.0 - step(0.001, abs(gg_subcells - 1.0)));
   float quad_width = InputSize.x / OutputSize.x;
   /* The black matrix is visibly thinner vertically than horizontally.  Give
    * 90% of the cell to the three colour apertures and the final 10% to the
    * vertical boundary.  Area coverage makes that 0.4 output pixels wide at
    * 4x instead of the former, over-heavy full pixel. */
   float q_r = periodic_box_coverage(cell.x, quad_width, 0.00, 0.30);
   float q_g = periodic_box_coverage(cell.x, quad_width, 0.30, 0.60);
   float q_b = periodic_box_coverage(cell.x, quad_width, 0.60, 0.90);
   float q_gap = periodic_box_coverage(cell.x, quad_width, 0.90, 1.00);
   vec3 stripe_quad =
      q_r * mix(vec3(1.0), vec3(2.0, 0.5, 0.5), gg_subpixel) +
      q_g * mix(vec3(1.0), vec3(0.5, 2.0, 0.5), gg_subpixel) +
      q_b * mix(vec3(1.0), vec3(0.5, 0.5, 2.0), gg_subpixel) +
      q_gap * vec3(1.0 - gg_aperture);
   stripe = mix(stripe, stripe_quad, four_pixel_cell);
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
   float source_rows_per_pixel = InputSize.y / OutputSize.y;
   float vertical_scale = OutputSize.y / InputSize.y;
   float vertical_misalignment =
      step(0.001, abs(vertical_scale - floor(vertical_scale + 0.5)));
   float row_edge2 = mix(edge.y * edge.y,
                         edge2_coverage(cell.y, source_rows_per_pixel),
                         vertical_misalignment);
   float grid = (1.0 - gg_rowgap * row_edge2 - gg_colgap * edge.x * edge.x) /
                (1.0 - (gg_rowgap + gg_colgap) / 3.0);

   /* The Game Gear's cast is not subtle.  Between the CCFL and the STN stack
    * the whole panel sits blue-cyan: light greys come out pale blue and never
    * white, which is the first thing you notice in a photograph of one. */
   /* The lamp's own colour, measured off the hardware rather than assumed.
    * White on the real panel photographs at R:G:B 0.92 : 1.00 : 0.95 - a
    * faint green, which is what an STN over a CCFL looks like.  This used to
    * be a blue cast, which was the wrong direction and part of why the blue
    * came out so much stronger here than on the device. */
   vec3 lamp = mix(vec3(1.0), vec3(0.90, 1.00, 0.94), gg_tint);

   vec3 outc = rgb * stripe * grid * lamp * backlight(content_uv);

   /* Backlight saturation.  A cell cannot pass more light than there is
    * behind it, so the response rolls off rather than clipping: this lifts the
    * average, which is what looked dark, while the peaks the structure creates
    * approach one instead of being cut flat there. */
   outc = 1.0 - exp(-gg_bright * max(outc, vec3(0.0)));

   gl_FragColor = vec4(clamp(outc, 0.0, 1.0), 1.0);
}

#endif
