"""Generate the short, original clap used for experimental note feedback.

Only Python's standard library is required. Regeneration never changes music.
"""

from array import array
import math
from pathlib import Path
import random
import sys
import wave


def main() -> None:
    rate = 44100
    duration = 0.18
    rng = random.Random(721)
    high_pass = 0.0
    low_pass = 0.0
    previous_noise = 0.0
    high_decay = math.exp(-2 * math.pi * 650 / rate)
    low_mix = 1 - math.exp(-2 * math.pi * 6500 / rate)
    bursts = [(0.0, 1.0, 0.0035), (0.008, 0.85, 0.004), (0.018, 0.9, 0.005), (0.027, 0.65, 0.030)]
    samples = []
    for index in range(round(duration * rate)):
        time = index / rate
        noise = rng.uniform(-1, 1)
        high_pass = high_decay * (high_pass + noise - previous_noise)
        previous_noise = noise
        low_pass += low_mix * (high_pass - low_pass)
        envelope = sum(
            amplitude * min(1.0, (time - start) / 0.0004) * math.exp(-(time - start) / decay)
            for start, amplitude, decay in bursts if time >= start
        )
        fade = min(1.0, (duration - time) / 0.015)
        samples.append(low_pass * envelope * fade)
    gain = 0.65 * 32767 / max(abs(sample) for sample in samples)
    pcm = array("h", (round(sample * gain) for sample in samples))
    if sys.byteorder != "little":
        pcm.byteswap()
    path = Path(__file__).resolve().parents[1] / "assets/audio/clap.wav"
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(rate)
        output.writeframes(pcm.tobytes())
    print(f"Generated {path.name}: {duration:.2f}s, {rate} Hz, mono")


if __name__ == "__main__":
    main()
