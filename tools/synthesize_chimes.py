"""Pickup and lightning sounds for WIPE, from Python's standard library only.
Writes core.wav, pickup.wav, and zap.wav beside the original palette; the
checked-in WAV files are build inputs, so Python is not needed to build.
"""
from pathlib import Path
import math
import random
import struct
import wave

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'


def write(name, samples, level=.7):
    peak = max(abs(x) for x in samples) or 1.0
    with wave.open(str(OUT / f'{name}.wav'), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b''.join(struct.pack('<h', int(x / peak * level * 32767)) for x in samples))


def core():
    # A short glassy tick: two detuned partials with a fast decay.
    out = []
    n = int(RATE * .07)
    for i in range(n):
        t = i / RATE
        env = min(t / .002, 1.0) * math.exp(-t * 55)
        out.append(env * (math.sin(math.tau * 1760 * t) + .45 * math.sin(math.tau * 2637 * t)))
    return out


def pickup():
    # A rising three-note arpeggio: unmistakably a reward.
    out = []
    for k, freq in enumerate((880, 1109, 1319)):
        n = int(RATE * .075)
        for i in range(n):
            t = i / RATE
            env = min(t / .003, 1.0) * math.exp(-t * 18)
            out.append(env * (math.sin(math.tau * freq * t) + .3 * math.sin(math.tau * freq * 2 * t)))
    tail = int(RATE * .12)
    for i in range(tail):
        t = i / RATE
        out.append(math.exp(-t * 20) * .6 * math.sin(math.tau * 1319 * t))
    return out


def zap():
    # A lightning crack: a noise burst over a falling buzz.
    rng = random.Random(907)
    out = []
    n = int(RATE * .16)
    phase = 0.0
    for i in range(n):
        t = i / RATE
        p = i / n
        freq = 900 * (1 - p) + 120
        phase += math.tau * freq / RATE
        buzz = 1.0 if math.sin(phase) > 0 else -1.0
        env = min(t / .001, 1.0) * math.exp(-t * 24)
        out.append(env * (.55 * rng.uniform(-1, 1) + .45 * buzz))
    return out


OUT.mkdir(parents=True, exist_ok=True)
write('core', core(), .5)
write('pickup', pickup(), .75)
write('zap', zap(), .6)
