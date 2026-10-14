import argparse
import contextlib
import subprocess
from pathlib import Path

import eluate
import numpy as np
import soundfile as sf


def report(percent, stage):
    print(f"PROGRESS\t{percent}\t{stage}", flush=True)


def read_block(source, count, channels):
    if source is None:
        return np.zeros((count, channels), dtype=np.float32)
    block = source.read(count, dtype="float32", always_2d=True)
    if len(block) < count:
        block = np.pad(block, ((0, count - len(block)), (0, 0)))
    return block


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("video")
    parser.add_argument("workspace")
    parser.add_argument("ffmpeg")
    parser.add_argument("speech", type=float)
    parser.add_argument("music", type=float)
    parser.add_argument("effects", type=float)
    args = parser.parse_args()
    workspace = Path(args.workspace)
    workspace.mkdir(parents=True, exist_ok=True)
    original_path = workspace / "original.wav"
    report(0, "extract")
    subprocess.run(
        [args.ffmpeg, "-y", "-hide_banner", "-loglevel", "error", "-i", args.video,
         "-vn", "-ac", "2", "-ar", "48000", "-c:a", "pcm_s16le", str(original_path)],
        check=True,
    )
    last_percent = -1

    def on_progress(fraction, stage):
        nonlocal last_percent
        percent = min(80, int(fraction * 80))
        if percent != last_percent:
            last_percent = percent
            report(percent, stage)

    result = eluate.elute(
        str(original_path),
        outputs=("speech", "sfx"),
        output_dir=workspace,
        overwrite=True,
        on_progress=on_progress,
    )
    selected_path = workspace / "selected.wav"
    with contextlib.ExitStack() as stack:
        speech = stack.enter_context(sf.SoundFile(result.speech))
        effects = stack.enter_context(sf.SoundFile(result.sfx))
        original = stack.enter_context(sf.SoundFile(original_path)) if args.music > 0 else None
        length = original.frames if original is not None else max(speech.frames, effects.frames)
        channels = original.channels if original is not None else speech.channels
        output = stack.enter_context(
            sf.SoundFile(selected_path, mode="w", samplerate=48000, channels=channels,
                         format="WAV", subtype="PCM_16")
        )
        block_size = 48000 * 10
        for start in range(0, length, block_size):
            count = min(block_size, length - start)
            voice = read_block(speech, count, channels)
            effects_audio = read_block(effects, count, channels)
            if args.music > 0:
                mixed = read_block(original, count, channels) * args.music
                mixed += voice * (args.speech - args.music)
                mixed += effects_audio * (args.effects - args.music)
            else:
                mixed = np.zeros((count, channels), dtype=np.float32)
                mixed += voice * args.speech
                mixed += effects_audio * args.effects
            output.write(np.clip(mixed, -1, 1))
            report(80 + int((start + count) / length * 15), "mix")
    report(95, "encode")
    subprocess.run(
        [args.ffmpeg, "-y", "-hide_banner", "-loglevel", "error", "-i", str(selected_path),
         "-c:a", "aac", "-b:a", "256k", str(workspace / "selected.m4a")],
        check=True,
    )
    report(100, "encode")


if __name__ == "__main__":
    main()
