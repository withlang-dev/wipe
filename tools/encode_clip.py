"""Encode the deterministic acceptance recording using installed ffmpeg.
Only a development tool: the game itself requires With and raylib.
"""
from array import array
from pathlib import Path
import math
import shutil
import subprocess
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'out' / 'uat'
RATE = 44100
DURATION = 33
COUNT = RATE * DURATION


def read_wave(path):
    with wave.open(str(path), 'rb') as f:
        assert f.getsampwidth() == 2, f'Expected PCM16: {path}'
        samples = array('h', f.readframes(f.getnframes()))
        if sys.byteorder != 'little': samples.byteswap()
        return samples, f.getframerate(), f.getnchannels()


frames = list((OUT / 'frames').glob('frame_*.png'))
if len(frames) != 990:
    raise SystemExit(f'Expected 990 captured frames, found {len(frames)}')
ffmpeg = shutil.which('ffmpeg')
if not ffmpeg:
    raise SystemExit('ffmpeg is required only for encoding this development clip.')
music, rate, channels = read_wave(ROOT / 'assets/audio/ambient_house.wav')
assert rate == RATE and channels == 2
mix = array('f', (music[i % len(music)] / 32768 * .32 for i in range(COUNT * 2)))
effects = {name: read_wave(ROOT / f'assets/audio/{name}.wav') for name in ['shot', 'hit', 'kill', 'hurt', 'death']}
volumes = [.20, .24, .35, .55, .65]
for line in (OUT / 'recording-events.txt').read_text().splitlines():
    if not line.startswith('SFX '): continue
    _, frame, *events = line.split()
    frame = int(frame)
    flags = list(map(int, events))
    if flags[2]: flags[1] = 0
    if flags[4]: flags[3] = 0
    clock = frame / 60
    for index, (name, active) in enumerate(zip(effects, flags)):
        if not active: continue
        samples, source_rate, source_channels = effects[name]
        assert source_channels == 1
        pitch = 1.0
        if name == 'shot': pitch = .96 + (math.sin(clock * 73) + 1) * .04
        if name == 'kill': pitch = .9 + (math.sin(clock * 57) + 1) * .1
        step = source_rate / RATE * pitch
        start = round(frame / 60 * RATE)
        for j in range(min(int((len(samples) - 1) / step), COUNT - start)):
            pos = j * step
            lo = int(pos)
            fraction = pos - lo
            value = (samples[lo] * (1 - fraction) + samples[lo + 1] * fraction) / 32768 * volumes[index]
            mix[(start + j) * 2] += value
            mix[(start + j) * 2 + 1] += value
peak = max(abs(x) for x in mix)
gain = min(1.0, .95 / peak)
# Fade only the exported clip's endpoints. The in-game loop stays continuous.
for i in range(COUNT):
    fade = min(1.0, i / (RATE * .025), (COUNT - i - 1) / (RATE * .4))
    mix[i * 2] *= gain * fade
    mix[i * 2 + 1] *= gain * fade
pcm = array('h', (int(x * 32767) for x in mix))
if sys.byteorder != 'little': pcm.byteswap()
with wave.open(str(OUT / 'showcase-audio.wav'), 'wb') as f:
    f.setnchannels(2)
    f.setsampwidth(2)
    f.setframerate(RATE)
    f.writeframes(pcm.tobytes())
subprocess.run([
    ffmpeg, '-y', '-hide_banner', '-loglevel', 'warning',
    '-framerate', '30', '-i', str(OUT / 'frames/frame_%d.png'),
    '-i', str(OUT / 'showcase-audio.wav'), '-c:v', 'libx264',
    '-preset', 'medium', '-crf', '18', '-pix_fmt', 'yuv420p',
    '-c:a', 'aac', '-b:a', '192k', '-movflags', '+faststart',
    '-shortest', str(OUT / 'wipe-showcase.mp4'),
], check=True)
print(f'Encoded 33s showcase; mixed peak {20 * math.log10(peak):.2f} dBFS; safety gain {gain:.3f}')
