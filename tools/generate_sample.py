"""Generate TouchPattern's original 112 BPM sample track and matching chart.

Uses only Python's standard library. Audio and notes are deterministic;
the melody repeats across each demo/response pair while the backing continues.
"""

from array import array
import json
import math
from pathlib import Path
import random
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
RATE = 44100
BPM = 112
SECONDS_PER_BEAT = 60 / BPM
PATTERNS = [
    ("첫 인사", [(0, 0), (1, 1), (2, 2), (3, 3)]),
    ("쉼표 한 칸", [(0, 0), (1, 3), (3, 1)]),
    ("반 박자", [(0, 0), (0.5, 1), (1.5, 2), (2, 3), (3, 0)]),
    ("함께 치기", [(0, 0), (0, 3), (1, 1), (2, 1), (2, 2), (3, 3)]),
    ("엇박자", [(0, 2), (0.75, 0), (1.5, 3), (2.5, 1), (3, 2)]),
    ("빈자리 기억", [(0, 1), (0.5, 3), (2, 0), (2.5, 2), (3.5, 1)]),
    ("두 손의 대화", [(0, 0), (0, 1), (1, 2), (1.5, 3), (2.5, 0), (2.5, 3), (3.5, 2)]),
    ("마지막 메아리", [(0, 0), (0.5, 2), (1, 1), (1.75, 3), (2.5, 0), (3, 1), (3, 2)]),
]


def main() -> None:
    duration = 70 * SECONDS_PER_BEAT
    samples = array("f", [0.0]) * math.ceil(duration * RATE)
    rng = random.Random(112)

    def add(beat: float, seconds: float, voice) -> None:
        start = round(beat * SECONDS_PER_BEAT * RATE)
        for index in range(min(round(seconds * RATE), len(samples) - start)):
            samples[start + index] += voice(index / RATE)

    def tone(beat: float, midi: int, amplitude: float, duration_s: float = 0.35) -> None:
        frequency = 440 * 2 ** ((midi - 69) / 12)
        add(
            beat,
            duration_s,
            lambda t: amplitude
            * min(1, t / 0.006)
            * math.exp(-t * 12)
            * (math.sin(2 * math.pi * frequency * t) + 0.16 * math.sin(4 * math.pi * frequency * t)),
        )

    # A continuous backing, including an introductory count-in.
    chords = [(36, 48, 52, 55), (33, 45, 48, 52), (29, 41, 45, 48), (31, 43, 47, 50)]
    for beat in range(68):
        chord = chords[max(0, (beat - 4) // 8) % len(chords)]
        tone(beat, chord[0], 0.20, 0.45)
        if beat % 2 == 0:
            for midi in chord[1:]:
                tone(beat, midi + 12, 0.035, 0.45)
        if beat % 4 in (0, 2):
            add(beat, 0.22, lambda t: 0.28 * math.exp(-t * 23) * math.sin(2 * math.pi * (48 * t + 2.1 * (1 - math.exp(-30 * t)))))
        if beat % 4 in (1, 3):
            add(beat, 0.13, lambda t: 0.10 * math.exp(-t * 32) * rng.uniform(-1, 1))
        for subdivision in (0, 0.5):
            add(beat + subdivision, 0.045, lambda t: 0.042 * math.exp(-t * 85) * rng.uniform(-1, 1))

    phrases = []
    for index, (name, notes) in enumerate(PATTERNS):
        show = 4 + index * 8
        response = show + 4
        phrases.append({
            "name": name,
            "show_beat": show,
            "response_beat": response,
            "length_beats": 4,
            "notes": [{"beat": beat, "cell": cell} for beat, cell in notes],
        })
        for start in (show, response):
            for beat, cell in notes:
                tone(start + beat, [72, 76, 79, 83][cell], 0.23)

    # Short fades keep the WAV clean at both ends.
    pcm = array("h")
    peak = max(abs(value) for value in samples)
    for index, value in enumerate(samples):
        fade = min(1.0, index / (RATE * 0.012), (len(samples) - index - 1) / (RATE * 0.5))
        pcm.append(round(value / max(1.0, peak) * 28000 * fade))
    if sys.byteorder != "little":
        pcm.byteswap()
    audio = ROOT / "assets/audio/first_echo.wav"
    audio.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(audio), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())

    chart = {
        "format_version": 1,
        "title": "First Echo",
        "artist": "TouchPattern · Original Demo",
        "bpm": BPM,
        "offset_seconds": 0.0,
        "audio": "../audio/first_echo.wav",
        "grid": {"rows": 2, "columns": 2},
        "phrases": phrases,
    }
    destination = ROOT / "assets/charts/first_echo.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(chart, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {audio.name}: {duration:.1f}s, {BPM} BPM, {sum(len(p['notes']) for p in phrases)} response notes")


if __name__ == "__main__":
    main()
