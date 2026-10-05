#!/usr/bin/env python3
"""Generate an original, short bell; no downloaded sound assets."""
import math, struct, wave
from pathlib import Path
path = Path(__file__).resolve().parents[1] / 'Sources/PomodoroApp/Resources/bell.wav'
rate = 44100
with wave.open(str(path), 'wb') as audio:
    audio.setnchannels(1); audio.setsampwidth(2); audio.setframerate(rate)
    frames = []
    for i in range(int(rate * 0.7)):
        t = i / rate
        attack = min(1, t / 0.004)
        tail = min(1, (0.7 - t) / 0.04)
        value = sum(g * math.sin(2 * math.pi * f * t) * math.exp(-d * t) for f, g, d in [(880, .5, 7), (1768, .22, 10), (2370, .12, 14)])
        frames.append(struct.pack('<h', int(32767 * .75 * attack * tail * value)))
    audio.writeframes(b''.join(frames))
print(path)
