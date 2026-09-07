/*
 * Game Gear LCD, pass 1: panel response.
 *
 * The Game Gear's STN panel is slow, which is the single most recognisable
 * thing about it: anything that moves leaves a trail.  The response is also
 * asymmetric - a cell falls to dark noticeably slower than it rises to light -
 * so a bright sprite crossing a dark background drags a tail behind it while
 * its leading edge stays reasonably crisp.
 *
 * RetroArch's GLSL path exposes the previous input frames rather than a
 * feedback buffer, so this is a short weighted history instead of an IIR.
 * Four taps is enough to read as smear without turning into a double image.
 */

#pragma parameter gg_rise "LCD rise speed"  0.62 0.10 1.00 0.02
#pragma parameter gg_fall "LCD fall speed"  0.34 0.05 1.00 0.02

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
uniform sampler2D PrevTexture;
uniform sampler2D Prev1Texture;
uniform sampler2D Prev2Texture;
uniform sampler2D Prev3Texture;

#ifdef PARAMETER_UNIFORM
uniform float gg_rise;
uniform float gg_fall;
#else
#define gg_rise 0.62
#define gg_fall 0.34
#endif

void main(void) {
   vec3 cur = texture2D(Texture,      vTex).rgb;
   vec3 p0  = texture2D(PrevTexture,  vTex).rgb;
   vec3 p1  = texture2D(Prev1Texture, vTex).rgb;
   vec3 p2  = texture2D(Prev2Texture, vTex).rgb;
   vec3 p3  = texture2D(Prev3Texture, vTex).rgb;

   /* What the cell was already showing, weighted towards the recent past. */
   vec3 history = (p0 * 0.42 + p1 * 0.28 + p2 * 0.18 + p3 * 0.12);

   /* Rising towards light is quicker than falling towards dark, per channel. */
   vec3 rising = step(history, cur);
   vec3 speed  = mix(vec3(gg_fall), vec3(gg_rise), rising);

   gl_FragColor = vec4(mix(history, cur, speed), 1.0);
}

#endif
