/*
 * Game Gear LCD, final optical crosstalk pass.
 *
 * The panel pass draws the physical R/G/B apertures and their dark boundary.
 * A real cover lens and STN stack do not leave those aperture edges perfectly
 * sharp: colour spreads into the neighbouring output pixels.  Preserve most
 * centre-pixel luminance so one-dot black shadows remain visible, while
 * allowing substantially more chroma than luma to cross the boundary.
 */

#pragma parameter gg_optics_chroma "Optical colour bleed" 1.00 0.00 1.00 0.02
#pragma parameter gg_optics_luma   "Optical luma bleed"   0.32 0.00 1.00 0.02

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
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
#endif

varying vec2 vTex;
uniform sampler2D Texture;
uniform vec2 TextureSize;

#ifdef PARAMETER_UNIFORM
uniform float gg_optics_chroma;
uniform float gg_optics_luma;
#else
#define gg_optics_chroma 1.00
#define gg_optics_luma   0.32
#endif

void main(void) {
   vec2 px = 1.0 / TextureSize;
   vec3 centre = texture2D(Texture, vTex).rgb;
   vec3 spread =
      (4.0 * centre +
       texture2D(Texture, vTex + vec2(-px.x, 0.0)).rgb +
       texture2D(Texture, vTex + vec2( px.x, 0.0)).rgb +
       texture2D(Texture, vTex + vec2(0.0, -px.y)).rgb +
       texture2D(Texture, vTex + vec2(0.0,  px.y)).rgb) / 8.0;

   const vec3 LUMA = vec3(0.299, 0.587, 0.114);
   float centre_luma = dot(centre, LUMA);
   float spread_luma = dot(spread, LUMA);
   vec3 centre_chroma = centre - vec3(centre_luma);
   vec3 spread_chroma = spread - vec3(spread_luma);

   float out_luma = mix(centre_luma, spread_luma, gg_optics_luma);
   vec3 out_chroma = mix(centre_chroma, spread_chroma, gg_optics_chroma);
   gl_FragColor = vec4(clamp(vec3(out_luma) + out_chroma, 0.0, 1.0), 1.0);
}

#endif
