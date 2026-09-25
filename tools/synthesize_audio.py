"""Rebuild the original WIPE sound palette using only Python's standard library.
The checked-in WAV files are build inputs; Python is not needed to build/run.
"""
from pathlib import Path
import math
import random
import struct
import wave

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'


def render(name, duration, start, end, noise, decay, overtone=0.0):
    rng = random.Random(174)
    phase = 0.0
    samples = []
    count = int(RATE * duration)
    for i in range(count):
        t = i / RATE
        p = i / count
        freq = end + (start - end) * (1 - p) ** 2
        phase += 2 * math.pi * freq / RATE
        attack = min(t / 0.002, 1.0)
        envelope = attack * math.exp(-p * decay) * (1 - p)
        tone = math.sin(phase) + overtone * math.sin(phase * 2.01)
        sample = (tone * (1 - noise) + rng.uniform(-1, 1) * noise) * envelope
        weight = {'shot': .45, 'hit': .25, 'kill': .55, 'hurt': .7, 'death': .9}[name]
        sub = math.sin(2 * math.pi * (58 * t + .45 * (1 - math.exp(-t * 42))))
        sample += sub * weight * attack * math.exp(-t * (6 if name == 'death' else 18)) * (1 - p)
        samples.append(sample)
    with wave.open(str(OUT / f'{name}.wav'), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        peak = max(abs(x) for x in samples)
        f.writeframes(b''.join(struct.pack('<h', int(x / peak * .78 * 32767)) for x in samples))


OUT.mkdir(parents=True, exist_ok=True)
render('shot', .085, 1350, 350, .12, 5)
render('hit', .075, 720, 220, .5, 6)
render('kill', .19, 280, 80, .32, 3, .3)
render('hurt', .25, 170, 45, .3, 2, .25)
render('death', .65, 200, 28, .42, 2.2, .4)

# A 16-bar ambient-house bed at 110 BPM. Original harmony/synthesis;
# designed to loop, with restrained percussion and bass space for gameplay.
from array import array

RATE = 44100
BPM = 110
BEAT = 60 / BPM
DURATION = 16 * 4 * BEAT
N = round(DURATION * RATE)
music = array('f', [0.0]) * (N * 2)
rng = random.Random(3026)
TAU = math.tau


def add_event(start, duration, voice, gain=1.0, pan=0.0):
    # Fold reverb/delay tails around the loop so the seam stays continuous.
    start_sample = round(start * RATE)
    lg = math.sqrt((1 - pan) / 2)
    rg = math.sqrt((1 + pan) / 2)
    for j in range(round(duration * RATE)):
        value = voice(j / RATE) * gain
        index = ((start_sample + j) % N) * 2
        music[index] += value * lg
        music[index + 1] += value * rg


def kick(t):
    phase = TAU * (49 * t + 3.0 * (1 - math.exp(-t * 42)))
    body = math.sin(phase) * math.exp(-t * 8)
    click = math.sin(TAU * 1800 * t) * math.exp(-t * 170) * .08
    return (body + click) * min(t / .0015, 1)


roots = [55.0, 43.6535, 65.4064, 49.0]
chords = [
    [220.0, 261.6256, 329.6276, 391.9954, 493.8833],
    [174.6141, 220.0, 261.6256, 329.6276, 391.9954],
    [130.8128, 195.9977, 246.9417, 293.6648, 329.6276],
    [195.9977, 246.9417, 293.6648, 329.6276, 440.0],
]

# Broad, gently chorused pads; a breathing envelope leaves room for the kick.
for c, chord in enumerate(chords):
    chord_start = c * 16 * BEAT
    chord_duration = 16 * BEAT
    for voice_index, frequency in enumerate(chord):
        phase_offset = voice_index * .71
        def pad(t, f=frequency, phase=phase_offset):
            envelope = math.sin(math.pi * min(t / chord_duration, 1)) ** .5
            breathing = .78 + .22 * math.sin(TAU * t / (4 * BEAT))
            return (math.sin(TAU * f * t + phase) + .35 * math.sin(TAU * f * 1.002 * t + phase)) * envelope * breathing
        add_event(chord_start, chord_duration, pad, .035, (voice_index - 2) * .3)

for beat in range(64):
    t = beat * BEAT
    add_event(t, .8, kick, .38)
    # Rounded offbeat bass, with a quiet second harmonic for small speakers.
    f = roots[beat // 16]
    def bass(t, f=f):
        env = min(t / .016, 1) * math.exp(-t * 7) * min(max((.36 - t) / .045, 0), 1)
        return (math.sin(TAU * f * t) + .22 * math.sin(TAU * f * 2 * t)) * env
    add_event(t + BEAT * .48, .36, bass, .27)
    # Gentle high-pass noise hat and a low, soft clap on beats two/four.
    hat_noise = [rng.uniform(-1, 1) for _ in range(round(.12 * RATE) + 1)]
    def hat(t, noise=hat_noise):
        j = min(int(t * RATE), len(noise) - 1)
        return (noise[j] - noise[max(j - 1, 0)]) * math.exp(-t * 65)
    add_event(t + BEAT * .5, .12, hat, .024, .35)
    if beat % 2 == 1:
        clap_noise = [rng.uniform(-1, 1) for _ in range(round(.18 * RATE) + 1)]
        def clap(t, noise=clap_noise):
            return noise[min(int(t * RATE), len(noise)-1)] * math.exp(-t * 28) * min(t / .002, 1)
        add_event(t, .18, clap, .026, -.15)
    if beat % 4 == 2:
        note = chords[beat // 16][(beat // 4) % 5] * 2
        def bell(t, f=note):
            return (math.sin(TAU * f * t) + .15 * math.sin(TAU * f * 2 * t)) * math.exp(-t * 3.2) * min(t / .008, 1)
        pan = -.4 if beat % 8 == 2 else .4
        add_event(t + BEAT * .75, 2.0, bell, .045, pan)
        add_event(t + BEAT * 1.5, 2.0, bell, .016, -pan)
        add_event(t + BEAT * 2.25, 2.0, bell, .008, pan)

# Normalize with ample headroom. The loop is intentionally below effects.
peak = max(abs(x) for x in music)
pcm = array('h', (int(max(-1, min(1, x * .76 / peak)) * 32767) for x in music))
import sys
if sys.byteorder != 'little': pcm.byteswap()
with wave.open(str(OUT / 'ambient_house.wav'), 'wb') as f:
    f.setnchannels(2)
    f.setsampwidth(2)
    f.setframerate(RATE)
    f.writeframes(pcm.tobytes())
print(f'ambient_house.wav: {DURATION:.3f}s, 110 BPM, stereo, peak -2.4 dBFS')
