# WIPE: SURVIVAL

A native With + raylib twin-stick survival prototype. Luminous wireframes,
a reactive grid, Gaussian bloom, directional sparks, and a bass-led ambient
house soundtrack. One arena, one chaser type, one-hit kills, automatic fire,
and immediate retry.

## Build and play

Requires the With compiler and its raylib 6.0 dependency (declared in
`with.toml`). No other game/build dependency has been added.

```sh
with build
./out/bin/wipe
```

The build copies the checked-in audio and GLSL shaders beside the executable.
The executable resolves assets from its own directory, so it can be launched
from another working directory. When distributing it, include `out/bin/assets/`.
A desktop OpenGL 3.3 context and audio output are expected. Failure to load
required shaders/assets is reported instead of silently displaying substitutes.
An unavailable audio device permits silent play.

| Action | Keyboard/mouse | Controller |
| --- | --- | --- |
| Move | WASD or arrows | Left stick |
| Aim | Mouse | Right stick |
| Fire | Automatic | Automatic |
| Retry after death | Space | A / south face button |
| Performance overlay | F1 | — |
| Populate 350 enemies | F3 | — |
| Quit | Escape | — |

Xbox controllers use raylib's standard gamepad mapping. The first connected
pad is selected on every input sample, including reconnects. For the original
Steam Controller, use Steam Input with left-stick movement and right-trackpad
right-stick or mouse aiming; add the executable as a non-Steam game. Physical
Xbox/Steam Controller and Steam Deck validation remains a required hardware
acceptance step; software tests are not a substitute for those checks.

## Acceptance and performance

```sh
with build :test
with run test/test_main.w --debug-alloc
with build :uat
mkdir -p out/uat
./out/bin/uat > out/uat/capped-performance.txt
WIPE_BENCH=1 ./out/bin/uat > out/uat/uncapped-performance.txt
with build :audio-uat
./out/bin/audio-uat
```

The separate `uat` executable drives a deterministic fixture through 150,
350, and 512 enemies, sustained particles, death, and retry. Only this runner
disables contact damage and supplies automated aiming/movement. The playable
entry point contains neither behavior. Capped runs save gameplay/stress/death/
restart PNGs; uncapped runs measure throughput without screenshot I/O. The
histograms report 0.25 ms upper-bound buckets, mean, and peak. CPU render
submission is measured separately from `EndDrawing`; it is not GPU timer data.

The audio acceptance runner checks real playback, wrap across the loop seam,
and music continuity through a game reset. Subjective listening and controller
hardware acceptance are tracked separately in `docs/verification/report.md`.

## Showcase recording

The following optional development workflow uses the already-installed ffmpeg
and Python's standard library. Neither is needed to build or run the game.

```sh
with build :uat
mkdir -p out/uat/frames
WIPE_RECORD=1 ./out/bin/uat > out/uat/recording-events.txt
python3 tools/encode_clip.py
```

This creates `out/uat/wipe-showcase.mp4`: a 33-second, 30 FPS deterministic
recording of the real simulation/renderer, with music and event-synchronized
sound effects. Capture I/O is excluded from performance claims. The clip is
an automated fixture, not a human playthrough or a hardware certification.

## Code and assets

- `src/main.w`: playable lifecycle and fixed-step loop.
- `src/game.w`: deterministic simulation, preallocated pools, local separation.
- `src/tuning.w`: gameplay knobs, independent from presentation.
- `src/input.w`: radial deadzones, keyboard/mouse, gamepad selection.
- `src/presentation.w`: sharp gameplay geometry, effects, HUD, render passes.
- `src/shaders.w`: owned shaders and the narrow typed GPU-uniform boundary.
- `src/audio.w`: owned sound/music resources and per-frame playback.
- `src/uat.w`, `src/audio_uat.w`, `test/`: acceptance and measurement.

The original procedural WAV assets and shader sources are checked in. See
`assets/README.md` for provenance. Regenerate audio with
`python3 tools/synthesize_audio.py` only when changing the palette.
