# /// script
# requires-python = ">=3.10"
# dependencies = ["numpy"]
# ///
"""Makes every sound in assets/ from plain math, so the game needs no downloaded audio.

Run: uv run tools/make_sounds.py
"""

import wave
from pathlib import Path

import numpy as np

SR = 32000
ROOT = Path(__file__).resolve().parent.parent / "assets"


def save(path: Path, x: np.ndarray, peak: float = 0.8) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    data = (x * 32767).astype("<i2").tobytes()
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print(f"{path.relative_to(ROOT.parent)}  {len(x) / SR:.2f}s")


def times(dur: float) -> np.ndarray:
    return np.arange(int(dur * SR)) / SR


def phase(freq: np.ndarray | float, dur: float) -> np.ndarray:
    f = np.broadcast_to(freq, times(dur).shape)
    return 2 * np.pi * np.cumsum(f) / SR


def tri(ph: np.ndarray) -> np.ndarray:
    return 2 / np.pi * np.arcsin(np.sin(ph))


def soft_square(ph: np.ndarray) -> np.ndarray:
    return np.tanh(3 * np.sin(ph))


def env(dur: float, attack: float = 0.005, decay: float = 8.0) -> np.ndarray:
    t = times(dur)
    return np.minimum(t / attack, 1.0) * np.exp(-decay * t)


def fade_out(x: np.ndarray, sec: float = 0.02) -> np.ndarray:
    n = min(len(x), int(sec * SR))
    x[-n:] *= np.linspace(1, 0, n)
    return x


def noise(dur: float, seed: int = 1) -> np.ndarray:
    return np.random.default_rng(seed).uniform(-1, 1, len(times(dur)))


def lowpass(x: np.ndarray, amount: float) -> np.ndarray:
    """Very simple one-pole low-pass. amount near 1 = darker."""
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = acc * amount + v * (1 - amount)
        y[i] = acc
    return y


def midi(n: float) -> float:
    return 440.0 * 2 ** ((n - 69) / 12)


def bell(freq: float, dur: float, decay: float = 6.0) -> np.ndarray:
    ph = phase(freq, dur)
    return (np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.15 * np.sin(3.01 * ph)) * env(dur, 0.003, decay)


# ---------- sound effects ----------

def sfx_jump() -> np.ndarray:
    d = 0.16
    t = times(d)
    ph = phase(300 + 500 * (t / d) ** 0.7, d)
    return fade_out((0.6 * tri(ph) + 0.4 * soft_square(ph)) * env(d, 0.004, 9))


def sfx_boing() -> np.ndarray:
    d = 0.5
    t = times(d)
    f = 170 + 330 * (t / d) + 70 * np.sin(2 * np.pi * 17 * t) * np.exp(-3 * t)
    return fade_out(np.sin(phase(f, d)) * env(d, 0.004, 4.5))


def sfx_land() -> np.ndarray:
    d = 0.14
    t = times(d)
    thump = np.sin(phase(130 - 80 * t / d, d)) * env(d, 0.002, 22)
    dust = lowpass(noise(d, 3), 0.85) * env(d, 0.002, 30) * 2
    return fade_out(thump + dust)


def sfx_step() -> np.ndarray:
    d = 0.06
    return fade_out(lowpass(noise(d, 5), 0.7) * env(d, 0.002, 60))


def sfx_slide() -> np.ndarray:
    d = 1.0
    t = times(d)
    f = 520 + 600 * np.sin(np.pi * np.minimum(t / 0.75, 1.0)) ** 0.8 + 18 * np.sin(2 * np.pi * 7 * t)
    return fade_out(np.sin(phase(f, d)) * np.minimum(t / 0.05, 1.0) * np.exp(-1.6 * t), 0.15)


def sfx_kick() -> np.ndarray:
    d = 0.12
    t = times(d)
    pop = np.sin(phase(520 - 380 * t / d, d)) * env(d, 0.001, 30)
    click = noise(d, 9) * env(d, 0.0005, 120) * 0.5
    return fade_out(pop + click)


def sfx_sit() -> np.ndarray:
    d = 0.6
    out = np.zeros(len(times(d)))
    for i, n in enumerate([88, 91]):  # E6, G6
        start = int(i * 0.09 * SR)
        b = bell(midi(n), d - i * 0.09, 7)
        out[start:start + len(b)] += b
    return fade_out(out)


def sfx_home() -> np.ndarray:
    d = 0.9
    out = np.zeros(len(times(d)))
    for i, n in enumerate([84, 88, 91, 96]):  # C6 E6 G6 C7
        start = int(i * 0.07 * SR)
        b = bell(midi(n), d - i * 0.07, 6)
        out[start:start + len(b)] += b * 0.8
    return fade_out(out)


def sfx_checkpoint() -> np.ndarray:
    d = 1.0
    out = np.zeros(len(times(d)))
    for i, n in enumerate([79, 84, 88, 91, 96]):  # G5 C6 E6 G6 C7
        start = int(i * 0.06 * SR)
        b = bell(midi(n), d - i * 0.06, 5)
        out[start:start + len(b)] += b * (0.7 + 0.1 * i)
    t = times(d)
    sparkle = np.sin(phase(2400 + 800 * np.sin(2 * np.pi * 9 * t), d)) * env(d, 0.2, 5) * 0.15
    return fade_out(out + sparkle)


def sfx_fanfare() -> np.ndarray:
    notes = [(72, 0.12), (76, 0.12), (79, 0.12), (84, 0.7)]  # C5 E5 G5 C6
    total = sum(d for _, d in notes) + 0.3
    out = np.zeros(len(times(total)))
    pos = 0
    for n, d in notes:
        dd = d + 0.3
        ph = phase(midi(n), dd)
        t = times(dd)
        vib = 1 + 0.004 * np.sin(2 * np.pi * 6 * t)
        tone = (0.6 * tri(ph * vib) + 0.4 * soft_square(ph)) * env(dd, 0.01, 2.5 if d > 0.5 else 7)
        out[pos:pos + len(tone)] += tone
        pos += int(d * SR)
    return fade_out(out, 0.1)


# ---------- background music ----------

BPM = 112
BEAT = 60 / BPM
CHORDS = {  # bar chord: (bass root, chord tones)
    "C": (48, [60, 64, 67]),
    "G": (43, [59, 62, 67]),
    "Am": (45, [60, 64, 69]),
    "F": (41, [60, 65, 69]),
}
PROGRESSION = ["C", "G", "Am", "F"] * 4

A = [
    [(76, 1), (79, 1), (84, 1), (79, 1)],
    [(79, 1), (74, .5), (76, .5), (74, 1), (71, 1)],
    [(72, 1), (76, 1), (81, 1), (79, .5), (76, .5)],
    [(77, 1.5), (76, .5), (74, 2)],
    [(76, .5), (76, .5), (79, 1), (84, 1), (83, .5), (84, .5)],
    [(86, 1), (83, 1), (79, 2)],
    [(81, 1), (79, .5), (76, .5), (77, 1), (74, 1)],
    [(72, 1), (74, 1), (76, 2)],
]
B_END = [
    [(84, 1), (79, 1), (76, 1), (79, 1)],
    [(83, 1), (86, 1), (83, 1), (79, 1)],
    [(81, 1.5), (79, .5), (76, 1), (74, 1)],
    [(77, 1), (76, 1), (74, 1), (None, 1)],
]
MELODY = A + A[:4] + B_END


def music() -> np.ndarray:
    bar = 4 * BEAT
    length = int(len(PROGRESSION) * bar * SR)
    out = np.zeros(length)

    def add(sound: np.ndarray, at: float, gain: float) -> None:
        # Wrap the tail around to the start, so the loop has no seam.
        start = int(at * SR) % length
        idx = (start + np.arange(len(sound))) % length
        np.add.at(out, idx, sound * gain)

    for b, name in enumerate(PROGRESSION):
        t0 = b * bar
        root, tones = CHORDS[name]
        for beat in (0, 2):  # bass on beats 1 and 3
            d = BEAT * 1.9
            ph = phase(midi(root), d)
            add((np.sin(ph) + 0.3 * tri(ph)) * env(d, 0.01, 2.2), t0 + beat * BEAT, 0.55)
        for beat in (1, 3):  # bouncy chord on beats 2 and 4
            for n in tones:
                d = BEAT * 0.8
                add(tri(phase(midi(n), d)) * env(d, 0.005, 7), t0 + beat * BEAT, 0.09)
        for beat in range(4):  # soft kick, light clap and shaker
            if beat in (0, 2):
                d = 0.18
                tt = times(d)
                add(np.sin(phase(110 - 65 * tt / d, d)) * env(d, 0.002, 18), t0 + beat * BEAT, 0.45)
            else:
                add(np.diff(noise(0.12, b * 4 + beat), prepend=0) * env(0.12, 0.001, 35), t0 + beat * BEAT, 0.08)
            for half in (0, 0.5):
                add(np.diff(noise(0.04, 99 + b * 8 + beat * 2 + int(half * 2)), prepend=0) * env(0.04, 0.001, 80),
                    t0 + (beat + half) * BEAT, 0.035)

        pos = t0
        for n, beats in MELODY[b]:
            d = beats * BEAT
            if n is not None:
                dd = d * 0.95 + 0.15
                tt = times(dd)
                ph = phase(midi(n) * (1 + 0.003 * np.sin(2 * np.pi * 5.5 * tt)), dd)
                tone = (0.75 * tri(ph) + 0.25 * np.sin(2 * ph)) * env(dd, 0.01, 2.0 / max(beats, 0.5))
                add(tone, pos, 0.3)
            pos += d
    return out


def main() -> None:
    for name, fn in {
        "jump": sfx_jump, "boing": sfx_boing, "land": sfx_land, "step": sfx_step,
        "slide": sfx_slide, "kick": sfx_kick, "sit": sfx_sit, "home": sfx_home, "fanfare": sfx_fanfare, "checkpoint": sfx_checkpoint,
    }.items():
        save(ROOT / "sfx" / f"{name}.wav", fn())
    save(ROOT / "music" / "park.wav", music(), peak=0.7)


if __name__ == "__main__":
    main()
