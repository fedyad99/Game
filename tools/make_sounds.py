"""Синтез всех звуков и музыки игры (без чужих файлов).
Запуск: python3 tools/make_sounds.py  ->  assets/audio/sfx/*.wav, assets/audio/music/*.ogg
Нужны numpy, scipy и ffmpeg (для музыки в ogg)."""
import os
import subprocess
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 22050
ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
SFX = os.path.join(ROOT, "sfx")
MUS = os.path.join(ROOT, "music")
os.makedirs(SFX, exist_ok=True)
os.makedirs(MUS, exist_ok=True)
rng = np.random.default_rng(42)


def t(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, r=None, curve=4.0):
    """Огибающая: быстрая атака, экспоненциальное затухание."""
    x = np.arange(n) / SR
    e = np.minimum(1.0, x / max(a, 1e-4))
    d = n / SR
    e *= np.exp(-curve * x / d) if r is None else np.exp(-x / r)
    return e


def noise(d):
    return rng.uniform(-1, 1, int(SR * d))


def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), hi / (SR / 2)], btype="band")
    return signal.lfilter(b, a, x)


def lp(x, f, order=2):
    b, a = signal.butter(order, f / (SR / 2), btype="low")
    return signal.lfilter(b, a, x)


def hp(x, f, order=2):
    b, a = signal.butter(order, f / (SR / 2), btype="high")
    return signal.lfilter(b, a, x)


def sweep_noise(d, f0, f1, q=0.6):
    """Шум с плавающей полосой (свист рассекаемого воздуха)."""
    x = noise(d)
    out = np.zeros_like(x)
    seg = 256
    for i in range(0, len(x), seg):
        k = i / len(x)
        f = f0 + (f1 - f0) * k
        lo, hi = max(40, f * (1 - q)), min(SR / 2 - 100, f * (1 + q))
        out[i:i + seg] = bp(x[max(0, i - seg):i + seg], lo, hi)[-len(x[i:i + seg]):]
    return out


def tone(freq, d, kind="sine"):
    tt = t(d)
    ph = 2 * np.pi * np.cumsum(np.broadcast_to(freq, tt.shape)) / SR
    if kind == "sine":
        return np.sin(ph)
    if kind == "tri":
        return signal.sawtooth(ph, 0.5)
    if kind == "saw":
        return signal.sawtooth(ph)
    if kind == "square":
        return signal.square(ph) * 0.6
    return np.sin(ph)


def pad(x, d):
    n = int(SR * d)
    return np.concatenate([x, np.zeros(max(0, n - len(x)))])[:n] if n > len(x) else x


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def at(x, delay):
    return np.concatenate([np.zeros(int(SR * delay)), x])


def save(name, x, gain=0.9):
    x = np.asarray(x, dtype=float)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * gain
    fade = min(200, len(x))
    x[-fade:] *= np.linspace(1, 0, fade)
    wavfile.write(os.path.join(SFX, name + ".wav"), SR, (x * 32767).astype(np.int16))


def note(n):
    """MIDI-нота -> частота."""
    return 440.0 * 2 ** ((n - 69) / 12)


def pluck(freq, d, bright=0.5):
    """Щипок струны (Карплус-Стронг)."""
    n = int(SR * d)
    period = max(2, int(SR / freq))
    buf = rng.uniform(-1, 1, period)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = (1 - bright * 0.5) * 0.5 * (buf[i % period] + buf[(i + 1) % period]) + bright * 0.25 * buf[i % period]
    return out


def bell(freq, d, decay=None):
    tt = t(d)
    out = np.zeros_like(tt)
    for mult, amp in [(1, 1), (2.76, 0.5), (5.4, 0.25), (8.93, 0.12)]:
        out += amp * np.sin(2 * np.pi * freq * mult * tt) * np.exp(-tt * (3 + mult) / (d if decay is None else decay))
    return out


# ---------------- Бой ----------------

def make_combat():
    # Взмах мечом
    d = 0.22
    save("swing", sweep_noise(d, 500, 2500) * env(int(SR * d), a=0.04, curve=5), 0.6)
    # Удар по врагу: глухой удар + щелчок
    d = 0.18
    thud = tone(np.linspace(180, 60, int(SR * d)), d) * env(int(SR * d), curve=10)
    click = hp(noise(0.03), 2000) * env(int(SR * 0.03), curve=8)
    save("hit", mix(thud, click * 0.5), 0.8)
    # Крит: удар + звон
    save("crit", mix(thud * 1.2, click * 0.6, bell(1200, 0.35) * 0.35), 0.9)
    # Выстрел арбалета: щелчок тетивы + свист
    d = 0.25
    twang = tone(np.linspace(420, 260, int(SR * d)), d, "tri") * env(int(SR * d), curve=12)
    save("arrow", mix(twang * 0.7, hp(noise(0.02), 1500) * 0.6, at(sweep_noise(0.15, 3000, 1500) * env(int(SR * 0.15), a=0.02) * 0.3, 0.02)), 0.6)
    # Огненный шар: вспышка + шипение
    d = 0.4
    fire = lp(noise(d), 1800) * env(int(SR * d), a=0.03, curve=4)
    crackle = (rng.random(int(SR * d)) > 0.995) * rng.uniform(-1, 1, int(SR * d))
    save("fireball", mix(fire, hp(crackle, 1500) * 2, tone(np.linspace(120, 300, int(SR * d)), d) * env(int(SR * d), curve=6) * 0.4), 0.6)
    # Взрыв
    d = 0.9
    boom = lp(noise(d), 500, 3) * env(int(SR * d), a=0.005, curve=5)
    save("explosion", mix(boom * 1.5, tone(np.linspace(90, 30, int(SR * d)), d) * env(int(SR * d), curve=6), hp(noise(0.08), 1000) * 0.4), 0.95)
    # Смерть скелета: стук костей
    parts = []
    for i in range(7):
        f = rng.uniform(900, 2200)
        clk = bp(noise(0.04), f * 0.7, f * 1.3) * env(int(SR * 0.04), curve=10)
        parts.append(at(clk * rng.uniform(0.4, 1.0), i * rng.uniform(0.035, 0.06)))
    save("bones", mix(*parts, lp(noise(0.5), 300) * env(int(SR * 0.5), curve=6) * 0.3), 0.7)
    # Герой получил урон
    d = 0.25
    save("hurt", mix(tone(np.linspace(260, 140, int(SR * d)), d, "saw") * env(int(SR * d), curve=7) * 0.5,
                     lp(noise(d), 800) * env(int(SR * d), curve=9)), 0.7)
    # Вихрь
    d = 0.6
    save("whirlwind", mix(sweep_noise(d, 400, 1800) * env(int(SR * d), a=0.1, curve=3),
                          at(sweep_noise(0.3, 1800, 600) * env(int(SR * 0.3), a=0.05) * 0.6, 0.3)), 0.7)
    # Залп
    save("volley", mix(*[at(mix(pluck(rng.uniform(300, 380), 0.2, 0.8) * 0.6, hp(noise(0.02), 2000) * 0.2), i * 0.025) for i in range(6)]), 0.7)
    # Лечение
    d = 0.5
    save("heal", mix(*[at(bell(note(n), 0.5) * 0.5, i * 0.07) for i, n in enumerate([72, 76, 79, 84])]), 0.6)
    # Рывок / телепорт
    d = 0.3
    save("dash", sweep_noise(d, 3000, 600) * env(int(SR * d), a=0.01, curve=5), 0.7)
    d = 0.45
    save("blink", mix(tone(np.linspace(300, 1600, int(SR * d)), d, "sine") * env(int(SR * d), a=0.01, curve=5) * 0.5,
                      sweep_noise(d, 4000, 1000) * env(int(SR * d), curve=6) * 0.4), 0.6)
    # Ледяная нова: звон стекла
    d = 0.8
    save("frost", mix(*[at(bell(rng.uniform(1500, 3200), 0.6) * 0.3, rng.uniform(0, 0.15)) for _ in range(8)],
                      hp(noise(d), 3000) * env(int(SR * d), a=0.01, curve=6) * 0.5), 0.6)
    # Боевой клич
    d = 0.7
    v = tone(np.linspace(150, 190, int(SR * d)) + 6 * np.sin(2 * np.pi * 6 * t(d)), d, "saw")
    save("warcry", lp(v, 1200) * env(int(SR * d), a=0.05, curve=3), 0.7)
    # Ловушка: металлический лязг
    save("trap", mix(bell(700, 0.4) * 0.6, bell(1033, 0.3) * 0.4, hp(noise(0.05), 2500) * 0.5), 0.7)
    # Рёв босса
    d = 1.4
    growl = tone(np.linspace(80, 55, int(SR * d)) + 8 * np.sin(2 * np.pi * 11 * t(d)), d, "saw")
    save("boss_roar", mix(lp(growl, 700) * env(int(SR * d), a=0.15, curve=2.5), lp(noise(d), 400) * env(int(SR * d), a=0.1, curve=3) * 0.6), 0.95)
    # Удар босса о землю
    d = 0.8
    save("slam", mix(lp(noise(d), 250, 3) * env(int(SR * d), curve=6) * 2, tone(np.linspace(70, 25, int(SR * d)), d) * env(int(SR * d), curve=5)), 0.95)
    # Подбор сферы здоровья / монеты
    save("pickup", mix(bell(note(84), 0.25) * 0.5, at(bell(note(91), 0.3) * 0.5, 0.06)), 0.6)
    save("coin", mix(bell(2400, 0.2) * 0.5, at(bell(3200, 0.25) * 0.4, 0.05)), 0.5)
    # Новый уровень
    save("level_up", mix(*[at(mix(bell(note(n), 0.6) * 0.5, tone(note(n), 0.3, "tri") * env(int(SR * 0.3), curve=6) * 0.2), i * 0.09)
                           for i, n in enumerate([60, 64, 67, 72, 76])]), 0.8)
    # Победа / поражение
    save("victory", mix(*[at(mix(bell(note(n), 1.2) * 0.5, tone(note(n), 0.8, "tri") * env(int(SR * 0.8), curve=3) * 0.25), d0)
                          for n, d0 in [(60, 0), (64, 0.15), (67, 0.3), (72, 0.45), (67, 0.75), (72, 0.9), (76, 0.9), (79, 0.9)]]), 0.85)
    save("defeat", mix(*[at(tone(note(n), 0.9, "tri") * env(int(SR * 0.9), a=0.02, curve=3) * 0.5, i * 0.35)
                         for i, n in enumerate([62, 61, 60, 55])]), 0.7)


# ---------------- Интерфейс ----------------

def make_ui():
    d = 0.06
    save("click", mix(bp(noise(d), 1500, 4000) * env(int(SR * d), curve=14), tone(900, d) * env(int(SR * d), curve=16) * 0.5), 0.5)
    d = 0.04
    save("hover", tone(1400, d) * env(int(SR * d), curve=12), 0.25)
    save("tab", mix(pluck(note(67), 0.25, 0.3) * 0.7, at(pluck(note(74), 0.25, 0.3) * 0.5, 0.04)), 0.5)
    save("card_flip", sweep_noise(0.15, 1500, 4000) * env(int(SR * 0.15), a=0.02, curve=6), 0.5)
    save("card_pick", mix(bell(note(79), 0.5) * 0.5, at(bell(note(86), 0.5) * 0.4, 0.05), sweep_noise(0.12, 2000, 5000) * 0.2), 0.7)
    save("equip", mix(bell(520, 0.3) * 0.5, bell(780, 0.25) * 0.3, bp(noise(0.06), 1500, 5000) * env(int(SR * 0.06), curve=10) * 0.6), 0.6)
    save("unequip", mix(bell(400, 0.25) * 0.4, bp(noise(0.05), 800, 3000) * env(int(SR * 0.05), curve=10) * 0.5), 0.5)
    save("error", tone(160, 0.25, "square") * env(int(SR * 0.25), a=0.01, curve=4), 0.4)
    # Таланты
    save("talent", mix(bell(note(76), 0.7) * 0.5, at(bell(note(83), 0.7) * 0.4, 0.05), tone(note(64), 0.5, "tri") * env(int(SR * 0.5), a=0.02, curve=4) * 0.3), 0.7)
    save("talent_big", mix(*[at(bell(note(n), 1.2) * 0.45, i * 0.06) for i, n in enumerate([64, 71, 76, 83, 88])],
                           tone(note(52), 1.2, "tri") * env(int(SR * 1.2), a=0.05, curve=3) * 0.3), 0.8)
    # Сундук: стук, скрип крышки, вспышка
    knocks = mix(*[at(lp(noise(0.08), 600) * env(int(SR * 0.08), curve=10) * (0.6 + 0.2 * i), i * 0.11) for i in range(3)])
    save("chest_shake", knocks, 0.8)
    d = 0.6
    creak = tone(np.linspace(180, 260, int(SR * d)) + 15 * np.sin(2 * np.pi * 23 * t(d)), d, "saw")
    save("chest_open", mix(bp(creak, 200, 1500) * env(int(SR * d), a=0.05, curve=3) * 0.6, at(lp(noise(0.15), 500) * env(int(SR * 0.15), curve=8), 0.5)), 0.8)
    for rar, notes in [("common", [72, 79]), ("rare", [72, 76, 79, 84]), ("epic", [69, 72, 76, 81, 84, 88]),
                       ("legendary", [60, 64, 67, 72, 76, 79, 84, 88, 91])]:
        sparkle = mix(*[at(bell(note(n), 1.0) * 0.4, i * 0.05) for i, n in enumerate(notes)])
        swell = tone(note(notes[0] - 12), 1.2, "tri") * env(int(SR * 1.2), a=0.08, curve=3) * (0.15 + 0.05 * len(notes) / 3)
        save("reveal_" + rar, mix(sparkle, swell, hp(noise(0.8), 4000) * env(int(SR * 0.8), a=0.05, curve=4) * 0.15), 0.85)
    save("buy", mix(*[at(bell(2400 + i * 300, 0.2) * 0.4, i * 0.04) for i in range(4)]), 0.5)
    save("class_pick", mix(bell(note(67), 0.9) * 0.5, at(bell(note(74), 0.9) * 0.4, 0.08), at(bell(note(79), 1.0) * 0.4, 0.16),
                           sweep_noise(0.4, 600, 2500) * env(int(SR * 0.4), a=0.05) * 0.25), 0.8)


# ---------------- Музыка ----------------

def make_music(name, bpm, chords, melody_scale, seconds, dark=True, drums=True):
    beat = 60.0 / bpm
    n = int(SR * seconds)
    out = np.zeros(n + SR * 3)
    bar = beat * 4
    bars = int(seconds / bar)
    for b in range(bars):
        root = chords[b % len(chords)]
        t0 = b * bar
        # Пэд: мягкий аккорд
        for k, iv in enumerate([0, 3 if dark else 4, 7, 12]):
            f = note(root + iv)
            d = bar + 0.3
            x = (tone(f, d, "tri") * 0.6 + tone(f * 1.005, d, "sine") * 0.4)
            x = lp(x, 1200) * np.minimum(1, t(d) / 0.4) * np.minimum(1, (d - t(d)) / 0.4)
            s = int(SR * t0)
            out[s:s + len(x)] += x * 0.08
        # Бас
        for q in range(4):
            f = note(root - 12)
            d = beat * 0.9
            x = tone(f, d, "sine") * env(int(SR * d), a=0.01, curve=3)
            s = int(SR * (t0 + q * beat))
            out[s:s + len(x)] += x * 0.22
        # Мелодия: щипки по гамме
        for q in range(8):
            if rng.random() < (0.55 if drums else 0.4):
                deg = melody_scale[rng.integers(len(melody_scale))]
                x = pluck(note(root + 12 + deg), beat * 1.5, 0.25)
                s = int(SR * (t0 + q * beat / 2))
                out[s:s + len(x)] += x * 0.12
        if drums:
            for q in range(4):
                s = int(SR * (t0 + q * beat))
                if q % 2 == 0:
                    k = tone(np.linspace(120, 45, int(SR * 0.25)), 0.25) * env(int(SR * 0.25), curve=8)
                    out[s:s + len(k)] += k * 0.35
                else:
                    sn = bp(noise(0.15), 800, 4000) * env(int(SR * 0.15), curve=10)
                    out[s:s + len(sn)] += sn * 0.12
                hh = hp(noise(0.04), 6000) * env(int(SR * 0.04), curve=10)
                s2 = int(SR * (t0 + q * beat + beat / 2))
                out[s2:s2 + len(hh)] += hh * 0.06
    # Хвост сворачиваем в начало, чтобы петля была бесшовной
    tail = out[n:]
    out = out[:n]
    out[:len(tail)] += tail
    # Простая реверберация
    rev = np.zeros_like(out)
    for dl, g in [(0.083, 0.3), (0.127, 0.22), (0.191, 0.15), (0.263, 0.1)]:
        k = int(SR * dl)
        rev[k:] += out[:-k] * g
    out = out + rev
    out = out / np.max(np.abs(out)) * 0.8
    wav = os.path.join(MUS, name + ".wav")
    wavfile.write(wav, SR, (out * 32767).astype(np.int16))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "3", os.path.join(MUS, name + ".ogg")], check=True)
    os.remove(wav)


if __name__ == "__main__":
    make_combat()
    make_ui()
    minor = [0, 3, 5, 7, 10, 12]
    make_music("menu", 72, [57, 53, 55, 52], minor, 64, drums=False)       # Am F G Em — спокойно у костра
    make_music("battle", 110, [50, 50, 46, 48], minor, 52, drums=True)     # Dm Dm Bb C — бодро
    make_music("boss", 128, [45, 46, 45, 44], [0, 1, 3, 7, 8], 45, drums=True)  # напряжённо
    print("ok")
