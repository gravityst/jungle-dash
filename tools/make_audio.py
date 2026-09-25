#!/usr/bin/env python3
"""Generates the synthesised sound effects that were added after the first pass.

Every sound in this game is made from maths rather than recorded or downloaded,
which is why there is nothing to license. Pure standard library — no numpy, no
scipy, nothing to install. Run it with:

    python3 tools/make_audio.py

Writes:
    audio/powerup.wav   a rising major arpeggio  — "you gained something"
    audio/launch.wav    a rising pitch sweep     — the trampoline bounce
    audio/shield.wav    a dull wooden thunk      — a shield taking a hit
    audio/whoosh.wav    a short airy sweep       — clearing an obstacle
    audio/step1.wav     a soft earth footfall    — the left foot
    audio/step2.wav     the same, a touch lower  — the right foot

Sounds are normalised to about -1.5 dBFS. The headroom matters because several
can overlap, and clipping on a sum is far uglier than a sound being quiet.
"""
import math
import struct
import wave

RATE = 44100
TAU = math.pi * 2.0


def write(path, buf):
    peak = max(abs(v) for v in buf) or 1.0
    frames = bytearray()
    for v in buf:
        clipped = max(-1.0, min(1.0, v / peak * 0.84))
        frames += struct.pack("<h", int(clipped * 32767))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(frames))
    print("wrote %-20s %.2f s" % (path, len(buf) / RATE))


def note(buf, start, freq, dur, amp, decay=7.0):
    """One plucked note, mixed into buf rather than overwriting it."""
    for i in range(int(dur * RATE)):
        idx = int(start * RATE) + i
        if idx >= len(buf):
            break
        t = i / RATE
        # Instant attack, exponential decay. A slow attack would smear an
        # arpeggio into a chord and lose the sense of rising.
        env = math.exp(-t * decay) * (1.0 - math.exp(-t * 900.0))
        buf[idx] += env * amp * (
            math.sin(TAU * freq * t)
            + 0.34 * math.sin(TAU * freq * 2.0 * t)
            + 0.16 * math.sin(TAU * freq * 3.0 * t))


def sweep(buf, start, f0, f1, dur, amp, curve=2.0):
    """A pitch glide. Phase is accumulated, NOT computed as sin(TAU*f(t)*t) —
    that classic mistake makes the frequency wrong everywhere except t=0 and
    produces an audible warble instead of a clean sweep."""
    phase = 0.0
    for i in range(int(dur * RATE)):
        idx = int(start * RATE) + i
        if idx >= len(buf):
            break
        t = i / RATE
        k = (t / dur) ** curve
        f = f0 + (f1 - f0) * k
        phase += TAU * f / RATE
        env = math.sin(math.pi * min(1.0, t / dur)) ** 0.7
        buf[idx] += env * amp * (math.sin(phase) + 0.25 * math.sin(phase * 2.0))


# --- powerup: a major arpeggio climbing, root/third/fifth/octave -------------
# Rising intervals read as a gain almost universally; the crash sound falls for
# the same reason in reverse.
buf = [0.0] * int(1.05 * RATE)
for start, freq in [(0.00, 660.0), (0.075, 831.0), (0.150, 988.0), (0.225, 1320.0)]:
    note(buf, start, freq, 0.80, 0.30)
note(buf, 0.225, 2640.0, 0.55, 0.075)   # a quiet octave sparkle on the last
write("audio/powerup.wav", buf)

# --- launch: the trampoline boing -------------------------------------------
# A fast upward sweep is the whole idea: the pitch going up is what makes it
# read as "you are going up". The slower second sweep underneath gives it some
# body so it doesn't sound like a laser.
buf = [0.0] * int(0.70 * RATE)
sweep(buf, 0.0, 150.0, 900.0, 0.42, 0.55, curve=1.6)
sweep(buf, 0.0, 75.0, 380.0, 0.55, 0.30, curve=2.2)
note(buf, 0.30, 1320.0, 0.40, 0.09)     # a little ring on the way out
write("audio/launch.wav", buf)

# --- shield: a wooden thunk, no pitch movement ------------------------------
# Deliberately DULL and falling, so it can never be mistaken for a pickup. It
# has to say "that cost you something" while still being a relief.
buf = [0.0] * int(0.55 * RATE)
sweep(buf, 0.0, 320.0, 110.0, 0.30, 0.55, curve=0.6)
note(buf, 0.0, 196.0, 0.45, 0.35, decay=13.0)
note(buf, 0.0, 294.0, 0.30, 0.16, decay=18.0)
write("audio/shield.wav", buf)

# --- footsteps ---------------------------------------------------------------
# A footfall on soft earth is a THUMP plus a scuff: a low body resonance that
# dies almost instantly, and a short hiss of loose dirt on top. Two versions,
# a couple of semitones apart, because a run is left-right-left and a single
# sample repeating at four steps a second is the fastest way to make a game
# sound cheap.
def footstep(path, pitch):
    buf = [0.0] * int(0.13 * RATE)
    seed = 4242
    for i in range(len(buf)):
        t = i / RATE
        seed = (1103515245 * seed + 12345) % 2147483648
        noise = (seed / 2147483648.0) * 2.0 - 1.0
        # The scuff: bright, and gone in about 30 ms.
        scuff = noise * math.exp(-t * 90.0) * 0.5
        # The thump: a low sine that drops in pitch as it decays, which is what
        # a soft surface does to an impact.
        f = 92.0 * pitch * (1.0 - 0.35 * min(1.0, t / 0.13))
        thump = math.sin(TAU * f * t) * math.exp(-t * 42.0)
        buf[i] = thump + scuff
    write(path, buf)


footstep("audio/step1.wav", 1.00)
footstep("audio/step2.wav", 0.89)

# --- whoosh: something passing close by -------------------------------------
# Filtered noise rather than a tone, because a near miss is air moving, not an
# object ringing. The band sweeps DOWN, which is the doppler of something you
# have just gone past rather than something approaching.
buf = [0.0] * int(0.34 * RATE)
state = 0.0
prev = 0.0
seed = 12345
for i in range(len(buf)):
    t = i / RATE
    # A tiny deterministic noise source — no random module, so the file is
    # byte-identical every time it is generated.
    seed = (1103515245 * seed + 12345) % 2147483648
    noise = (seed / 2147483648.0) * 2.0 - 1.0
    # One-pole low-pass whose cutoff falls over the sweep, plus a one-pole
    # high-pass, which together make a moving band.
    k = 0.55 - 0.42 * (t / 0.34)
    state += k * (noise - state)
    band = state - prev * 0.86
    prev = state
    env = math.sin(math.pi * min(1.0, t / 0.34)) ** 1.4
    buf[i] = band * env * 0.9
write("audio/whoosh.wav", buf)
