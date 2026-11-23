"""Synthesises the game's music and ambience (no samples, no licences).
Writes OGG loops into game/assets/audio. Deterministic: same seed, same sound."""
import numpy as np, subprocess, os, wave
SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '../assets/audio')
rng = np.random.default_rng(7)

def hz(m):  # MIDI note to Hz
    return 440.0 * 2 ** ((m - 69) / 12)

def band(x, lo, hi, sr=SR):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / sr)
    w = ((f >= lo) & (f <= hi)).astype(float)
    # soft edges
    w = np.convolve(w, np.ones(64) / 64, mode='same')
    return np.fft.irfft(X * w, len(x))

def env_pluck(n, a, d, sr=SR):
    t = np.arange(n) / sr
    return np.minimum(1, t / a) * np.exp(-t * d)

def add(buf, start, sig):
    s = int(start)
    if s >= len(buf): return
    e = min(len(buf), s + len(sig))
    buf[s:e] += sig[:e - s]

def rhodes(m, dur, vel=0.3):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(m)
    tone = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t * 6) + 0.12 * np.sin(2 * np.pi * 3 * f * t) * np.exp(-t * 9)
    trem = 1 + 0.18 * np.sin(2 * np.pi * 4.6 * t)
    return vel * tone * trem * env_pluck(n, 0.006, 1.4)

def bass(m, dur, vel=0.5):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(m)
    tone = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t * 8)
    e = env_pluck(n, 0.004, 3.2)
    e[-int(0.02 * SR):] *= np.linspace(1, 0, int(0.02 * SR))
    return vel * tone * e

def vibes(m, dur, vel=0.18):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(m)
    tone = np.sin(2 * np.pi * f * t) + 0.2 * np.sin(2 * np.pi * 4 * f * t) * np.exp(-t * 12)
    return vel * tone * env_pluck(n, 0.003, 2.0) * (1 + 0.25 * np.sin(2 * np.pi * 5.5 * t))

NOISE = rng.standard_normal(SR * 2)
BRUSH = band(NOISE, 800, 6000)
RIDE = band(NOISE, 6000, 14000)

def brush(vel):
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    e = np.minimum(1, t / 0.03) * np.exp(-t * 14)
    o = rng.integers(0, len(BRUSH) - n)
    return vel * BRUSH[o:o + n] * e

def ride(vel):
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    o = rng.integers(0, len(RIDE) - n)
    ping = np.sin(2 * np.pi * 5200 * t) * 0.15 + np.sin(2 * np.pi * 7400 * t) * 0.08
    return vel * (RIDE[o:o + n] * 0.8 + ping) * np.exp(-t * 11)

def save(name, x, loop_tail=None):
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.8
    pcm = (x * 32767).astype(np.int16)
    tmp = os.path.join(OUT, name + '.wav')
    with wave.open(tmp, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', tmp, '-c:a', 'libvorbis', '-q:a', '4', os.path.join(OUT, name + '.ogg')], check=True)
    os.remove(tmp)

def wrap(buf, length):
    """Fold the tail past the loop point back onto the start: seamless loops."""
    out = buf[:length].copy()
    tail = buf[length:]
    out[:len(tail)] += tail
    return out

# --------------------------------------------------------------- service music
def lounge(bpm, bars, prog, seed, swing=0.62, melody=True):
    global rng
    rng = np.random.default_rng(seed)
    beat = 60 / bpm
    length = int(bars * 4 * beat * SR)
    buf = np.zeros(length + SR * 3)
    for bar in range(bars):
        root, chord = prog[bar % len(prog)]
        t0 = bar * 4 * beat
        # Rhodes comping: beat 1 and the "and" of 2 (Charleston), lighter variant every other bar.
        hits = [(0, 1.4 * beat), (1 + swing, 1.6 * beat)] if bar % 2 == 0 else [(0.0, 2.6 * beat), (2 + swing, 1.2 * beat)]
        for off, dur in hits:
            for i, m in enumerate(chord):
                add(buf, (t0 + off * beat + i * 0.008) * SR, rhodes(m, dur + 1.0, 0.16))
        # Walking bass.
        nxt = prog[(bar + 1) % len(prog)][0]
        walk = [root, root + 7 if rng.random() < 0.5 else root + 3, root + 5 if rng.random() < 0.5 else root + 10, nxt + (1 if rng.random() < 0.5 else -1)]
        for k, m in enumerate(walk):
            add(buf, (t0 + k * beat) * SR, bass(m - 12, beat * 0.95, 0.42))
        # Brushes on every beat, accents on 2 and 4; ride in swung eighths.
        for k in range(4):
            add(buf, (t0 + k * beat) * SR, brush(0.025 if k % 2 == 0 else 0.05))
            add(buf, (t0 + k * beat) * SR, ride(0.014))
            if k % 2 == 1:
                add(buf, (t0 + (k + swing) * beat) * SR, ride(0.01))
        # A sparse vibraphone line in the second half of each 8 bars.
        if melody and bar % 8 >= 4:
            scale = [0, 2, 3, 5, 7, 9, 10]
            pos = rng.integers(0, 4)
            for k in range(rng.integers(2, 5)):
                step = rng.integers(0, 4) * 0.5 + (swing - 0.5 if rng.random() < 0.5 else 0)
                m = root + 12 + scale[(pos + k * rng.integers(1, 3)) % len(scale)]
                add(buf, (t0 + (k * 0.9 + step) * beat) * SR, vibes(m + 12, 1.2))
    return wrap(buf, length)

# ii–V–I–VI in C, then a minor turn: warm, unhurried.
service = [
    (50, [62, 65, 69, 72, 76]),  # Dm9
    (55, [59, 65, 69, 71, 76]),  # G13
    (48, [60, 64, 67, 71, 74]),  # Cmaj9
    (57, [61, 64, 67, 70, 72]),  # A7b9
    (50, [62, 65, 69, 72, 76]),
    (55, [59, 65, 68, 71, 74]),  # G7b9
    (52, [59, 64, 67, 71, 74]),  # Em9
    (57, [61, 64, 67, 70, 73]),  # A7
]
save('music_service', lounge(94, 16, service, 11))

# Title and prep: slower, just chords and bass, the room before the doors open.
title = [(53, [64, 69, 72, 76]), (52, [62, 67, 71, 74]), (50, [60, 65, 69, 72]), (55, [62, 65, 69, 71])]
def slow(bpm, bars, prog):
    beat = 60 / bpm
    length = int(bars * 4 * beat * SR)
    buf = np.zeros(length + SR * 4)
    for bar in range(bars):
        root, chord = prog[bar % len(prog)]
        t0 = bar * 4 * beat
        for i, m in enumerate(chord):
            add(buf, (t0 + i * 0.03) * SR, rhodes(m, 4 * beat + 2, 0.15))
            add(buf, (t0 + 2.5 * beat + i * 0.02) * SR, rhodes(m + 12, 2 * beat + 1, 0.04))
        add(buf, t0 * SR, bass(root - 12, 3.5 * beat, 0.35))
    return wrap(buf, length)
save('music_title', slow(64, 8, title))

# --------------------------------------------------------------- ambience
def crowd(seconds, voices, seed):
    r = np.random.default_rng(seed)
    n = int(seconds * SR)
    buf = np.zeros(n)
    t = np.arange(n) / SR
    for v in range(voices):
        noise = r.standard_normal(n)
        lo = r.uniform(250, 500)
        x = band(noise, lo, lo * r.uniform(3, 5))
        # Syllables come in bursts: talk for a while, then listen.
        syl = 0.5 + 0.5 * np.sin(2 * np.pi * r.uniform(3, 6) * t + r.uniform(0, 6))
        talk = (np.sin(2 * np.pi * r.uniform(0.05, 0.15) * t + r.uniform(0, 6)) > r.uniform(-0.3, 0.3)).astype(float)
        talk = np.convolve(talk, np.ones(4000) / 4000, mode='same')
        buf += x * syl * talk * r.uniform(0.5, 1.0)
    # Cutlery and glass.
    for k in range(int(seconds * 1.4)):
        s = r.integers(0, n - SR)
        m = int(0.12 * SR)
        tt = np.arange(m) / SR
        f = r.uniform(2400, 5200)
        buf[s:s + m] += np.sin(2 * np.pi * f * tt) * np.exp(-tt * r.uniform(30, 60)) * r.uniform(0.6, 2.0) * np.std(buf[:SR])
    # Seamless: crossfade the end into the start.
    x = int(1.5 * SR)
    fade = np.linspace(0, 1, x)
    buf[:x] = buf[:x] * fade + buf[-x:] * (1 - fade)
    return buf[:-x]
save('amb_room', crowd(32, 14, 3))

def kitchen(seconds, seed):
    r = np.random.default_rng(seed)
    n = int(seconds * SR)
    sizzle = band(r.standard_normal(n), 2500, 7000) * 0.5
    crackle = np.zeros(n)
    for k in range(int(seconds * 40)):
        s = r.integers(0, n - 400)
        crackle[s:s + 200] += r.standard_normal(200) * np.exp(-np.arange(200) / 30) * r.uniform(0.5, 3)
    hum = band(r.standard_normal(n), 60, 220) * 1.5
    t = np.arange(n) / SR
    buf = sizzle * (0.7 + 0.3 * np.sin(2 * np.pi * 0.13 * t)) + band(crackle, 1500, 9000) + hum
    x = int(1.0 * SR)
    fade = np.linspace(0, 1, x)
    buf[:x] = buf[:x] * fade + buf[-x:] * (1 - fade)
    return buf[:-x]
save('amb_kitchen', kitchen(20, 5))
print('ok', sorted(os.listdir(OUT)))
