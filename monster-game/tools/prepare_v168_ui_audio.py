"""Align navigation cues with the menu action, using the 0.10.67 originals.

Requires ffmpeg and numpy. By default, originals come from the v0.10.67 Git
tag. --source-project accepts an untouched copy of that Godot project.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
RATE = 44100
FRAME = 44
FILES = [f"v7_ui_{group:02d}_{variant}.ogg"
         for group in (1, 2) for variant in (1, 2)]


def decode(data):
    return np.frombuffer(subprocess.check_output([
        "ffmpeg", "-v", "error", "-i", "pipe:0", "-f", "f32le",
        "-ac", "1", "-ar", str(RATE), "pipe:1"], input=data), "<f4").copy()


def onset(samples, db=-30):
    frames = samples[:len(samples) // FRAME * FRAME].reshape(-1, FRAME)
    rms = np.sqrt(np.mean(frames.astype(np.float64) ** 2, axis=1))
    active = np.flatnonzero(rms >= 10 ** (db / 20))
    if not len(active):
        raise ValueError(f"Cue never reaches the onset threshold ({db} dBFS)")
    return int(active[0]) * FRAME


def prepare(source_project=None):
    entries = []
    for name in FILES:
        relative = Path("assets/audio/v7") / name
        if source_project:
            original = (source_project / relative).read_bytes()
        else:
            original = subprocess.check_output([
                "git", "show", f"v0.10.67:monster-game/{relative.as_posix()}"],
                cwd=ROOT)
        samples = decode(original)
        # Ignore the very quiet prelude. Keep 4 ms before the audible attack;
        # a 1.5 ms boundary fade prevents a splice click without a new ramp.
        start = max(0, onset(samples) - round(.004 * RATE))
        cropped = samples[start:].copy()
        fade = round(.0015 * RATE)
        cropped[:fade] *= np.linspace(0, 1, fade)
        encoded = subprocess.check_output([
            "ffmpeg", "-v", "error", "-f", "f32le", "-ar", str(RATE),
            "-ac", "1", "-i", "pipe:0", "-map_metadata", "-1",
            "-c:a", "libvorbis", "-q:a", "7", "-f", "ogg", "pipe:1"],
            input=cropped.astype("<f4").tobytes())
        output = decode(encoded)
        after = onset(output) / RATE
        assert after <= .008, (name, after)
        assert len(output) / RATE >= .20, name
        assert np.max(np.abs(output)) < 1, name
        (ROOT / relative).write_bytes(encoded)
        entries.append({
            "file": relative.as_posix(),
            "original_sha256": hashlib.sha256(original).hexdigest(),
            "sha256": hashlib.sha256(encoded).hexdigest(),
            "trimmed_ms": round(start / RATE * 1000, 3),
            "onset_before_ms": round(onset(samples) / RATE * 1000, 3),
            "onset_after_ms": round(after * 1000, 3),
            "duration_before_seconds": round(len(samples) / RATE, 6),
            "duration_seconds": round(len(output) / RATE, 6),
            "peak_dbfs": round(float(20 * np.log10(np.max(np.abs(output)))), 3),
        })
    manifest = {
        "version": "0.10.68", "source_tag": "v0.10.67",
        "scope": "UI_01 confirm/open and UI_02 back; both variants",
        "processing": "Crop to 4 ms before the first 1 ms RMS frame at -30 dBFS; 1.5 ms boundary fade; preserve gain and tail; mono 44100 Hz Vorbis quality 7.",
        "measurement": "Decoded output, 1 ms RMS frames, -30 dBFS threshold. Excludes operating system and audio device latency.",
        "files": entries,
    }
    report_dir = ROOT / "assets/audio/v168"
    report_dir.mkdir(parents=True, exist_ok=True)
    (report_dir / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    for entry in entries:
        print(f"{entry['file']}: {entry['onset_before_ms']} -> {entry['onset_after_ms']} ms; cropped {entry['trimmed_ms']} ms")
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-project", type=Path)
    args = parser.parse_args()
    prepare(args.source_project)
