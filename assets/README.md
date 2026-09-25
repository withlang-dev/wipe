# Original project assets

All included graphics, GLSL shader sources, synthesized effects, and music are
original project material. No downloaded samples, character art, third-party
music, or fonts have been added. The built-in raylib font is used by the HUD.

`audio/` contains five PCM16 effects and a 16-bar, 110 BPM stereo ambient-house
loop (34.909 seconds). The music combines a rounded kick, offbeat sub/mid bass,
chorused pads, sparse bell delays, and restrained percussion. Effect synthesis
adds a low body layer while leaving headroom for concurrent music and events.

`tools/synthesize_audio.py` reproducibly generates these WAVs using only the
Python standard library. The WAVs are build inputs; Python is not a build or
runtime dependency. `tools/encode_clip.py` is an optional development-only
recording encoder using the user's installed ffmpeg.

The four GLSL 330 shaders in `shaders/` implement the deforming grid,
bright-pass extraction, separable Gaussian blur, and scene/bloom composition.
No external shader package or engine is used.

Audio technical checks do not replace a subjective mix review on headphones
and Steam Deck speakers. The current soundtrack is an original procedural
production candidate for that review, not a claim of completed mastering.
