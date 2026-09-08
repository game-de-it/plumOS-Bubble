/*
 * Game Gear LCD, pass 1: panel response.
 *
 * The Game Gear's STN panel is slow, which is the single most recognisable
 * thing about it: anything that moves leaves a trail.  The response is also
 * asymmetric - a cell falls to dark noticeably slower than it rises to light -
 * so a bright sprite crossing a dark background drags a tail behind it while
 * its leading edge stays reasonably crisp.
 *
 * RetroArch only exposes seven raw previous input frames, which is too short
 * for the requested twelve-frame response.  The preset therefore feeds this
 * pass's previous output back as FeedbackTexture.  Alpha stores the age of a
 * falling transition, allowing the trail to reach the current frame exactly
 * on frame twelve instead of leaving an infinitely small recursive remainder.
 */

#pragma parameter gg_rise "LCD rise speed" 0.62 0.10 1.00 0.02
#pragma parameter gg_trail_frames "LCD trail frames" 12.0 1.0 30.0 1.0

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
uniform sampler2D FeedbackTexture;

#ifdef PARAMETER_UNIFORM
uniform float gg_rise;
uniform float gg_trail_frames;
#else
#define gg_rise 0.62
#define gg_trail_frames 12.0
#endif

void main(void) {
   vec3 cur = texture2D(Texture, vTex).rgb;
   vec4 feedback = texture2D(FeedbackTexture, vTex);
   vec3 history = feedback.rgb;

   /* Preserve almost the same strength as the exponential response over the
    * first few frames, then curve smoothly to zero: retention at age n is
    * ((N-n)/N)^2.  Encoding age in alpha makes N a real finite lifetime. */
   float frames = max(gg_trail_frames, 1.0);
   float previous_age = floor(feedback.a * frames + 0.5);
   float falling_delta = max(max(history.r - cur.r, history.g - cur.g),
                             history.b - cur.b);
   /* Pass 0 is stored as RGBA8 while the core commonly supplies RGB565.
    * Differences below two 8-bit levels are storage conversion, not motion.
    * Treating them as a new fall restarts the finite counter forever on a
    * static image. */
   float settle_epsilon = 2.0 / 255.0;
   vec3 absolute_delta = abs(history - cur);
   float largest_delta = max(max(absolute_delta.r, absolute_delta.g),
                             absolute_delta.b);
   float has_change = step(settle_epsilon, largest_delta);
   float has_falling = step(settle_epsilon, falling_delta) * has_change;
   float next_age = min(previous_age + 1.0, frames) * has_falling;
   float remaining = max(frames - previous_age, 1.0);
   float next_remaining = max(frames - next_age, 0.0);
   float retention = (next_remaining * next_remaining) /
                     (remaining * remaining);
   /* Snap sub-epsilon falling channels to the current sample. Otherwise a
    * value too small to start the age counter would remain in feedback. */
   float fall_speed = mix(1.0, 1.0 - retention, has_falling);
   vec3 rising = step(history, cur);
   vec3 speed = mix(vec3(fall_speed), vec3(gg_rise), rising);
   vec3 response = mix(history, cur, speed);
   response = mix(cur, response, has_change);

   gl_FragColor = vec4(response, next_age / frames);
}

#endif
