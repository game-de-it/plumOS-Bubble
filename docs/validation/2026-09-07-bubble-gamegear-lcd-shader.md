# Bubble Game Gear LCD shader validation

Date: 2026-09-07

## Scope

Make the dedicated Game Gear LCD GLSL preset usable from the normal frontend
route without changing RetroArch behavior for any other system. The shader is
independent from GGFE; GGFE must resolve to a RetroArch profile for it to apply.

## Host contract

- The persistent RetroArch cfg retains `video_shader_enable = "false"`.
- `system=gamegear` selects `video_driver=gl`, `video_context_driver=kms`,
  enables shaders in the launch append cfg, and supplies
  `config/shaders/gamegear-lcd.glslp` through `--set-shader`.
- A Game Gear launch with `panel-only` selects the diagnostic one-pass preset.
- A Game Gear launch with `off` returns to the existing unshaded route.
- Invalid preset modes fail before RetroArch starts.
- A non-Game Gear software-core launch remains on plain DRM with no shader.
- Factory shaders seed missing files but preserve an existing user-edited file.

## Device acceptance

Pending. Use the validation hold so the frontend and RetroArch never draw the
panel concurrently. Test in this order:

1. Panel-only preset: GLSL compile/link, Mali/KMS renderer, colour and cell
   structure, frame rate, audio, and clean return.
2. Full preset: previous-frame binding, brightness parity with panel-only,
   movement trail, frame rate, audio, and clean return.
3. Normal frontend Game Gear route: automatic full preset and clean FE return.
4. Non-Game Gear control route: no Game Gear preset and unchanged display.

Physical-panel colour, cell structure, response trail and perceived smoothness
require user observation and cannot be accepted from process/log evidence alone.
