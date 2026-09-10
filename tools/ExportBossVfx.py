"""Export LibreSprite-authored boss PNGs, preserving pixels and 400 ms timing.

Run with the bundled Python and --exe pointing to an ASCII-path LibreSprite.
The installed v1.1 JS FrameProperties command is GUI-only, so timing metadata
uses the official format: https://github.com/aseprite/aseprite/blob/main/docs/ase-file-specs.md
No image pixels are authored or modified by this script.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
from datetime import datetime

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DURATIONS = [33, 33, 34] * 4
GIF_DURATIONS = [30, 30, 40] * 4


def set_ase_timing(path):
    data = bytearray(path.read_bytes())
    size, magic, frames, width, height, depth = struct.unpack_from("<I5H", data)
    assert (size, magic, frames, width, height, depth) == (len(data), 0xA5E0, 12, 128, 64, 32)
    # File-header legacy speed is at byte 18; each frame duration is at +8.
    struct.pack_into("<H", data, 18, DURATIONS[0])
    offset = 128
    for duration in DURATIONS:
        length, frame_magic = struct.unpack_from("<IH", data, offset)
        assert length >= 16 and frame_magic == 0xF1FA and offset + length <= len(data)
        struct.pack_into("<H", data, offset + 8, duration)
        offset += length
    assert offset == len(data)
    path.write_bytes(data)


def set_gif_timing(path):
    # GIF89a GCE delay uses 1/100 seconds. Only those two-byte fields change.
    data = bytearray(path.read_bytes())
    assert data[:6] in (b"GIF89a", b"GIF87a")
    packed = data[10]
    offset = 13 + (3 * (2 << (packed & 7)) if packed & 128 else 0)
    delays, images = [], 0
    while data[offset] != 0x3B:
        marker = data[offset]
        offset += 1
        if marker == 0x21:
            label = data[offset]
            offset += 1
            if label == 0xF9:
                assert data[offset] == 4
                delays.append(offset + 2)
        else:
            assert marker == 0x2C
            images += 1
            packed = data[offset + 8]
            offset += 9 + (3 * (2 << (packed & 7)) if packed & 128 else 0)
            offset += 1  # LZW minimum code size.
        while data[offset]:
            offset += 1 + data[offset]
        offset += 1
    assert images == len(delays) == 12, (path, images, len(delays))
    for offset, duration in zip(delays, GIF_DURATIONS):
        struct.pack_into("<H", data, offset, duration // 10)
    path.write_bytes(data)


def rgba(path):
    with Image.open(path) as image:
        assert image.size == (128, 64), (path, image.size)
        return image.convert("RGBA").tobytes()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--exe", required=True, type=Path)
    args = parser.parse_args()
    assert args.exe.is_file() and str(args.exe).isascii(), "Use the verified ASCII portable executable"
    os.chdir(ROOT)
    qa = Path("build/qa/libresprite-vfx-export")
    qa.mkdir(parents=True, exist_ok=True)
    profile = ROOT / "build/qa" / ("profile-libresprite-export-" + datetime.now().strftime("%Y%m%d-%H%M%S"))
    profile.mkdir()
    env = os.environ.copy()
    env.update(APPDATA=str(profile), LOCALAPPDATA=str(profile))
    output = Path("art/boss_vfx")
    output.mkdir(parents=True, exist_ok=True)
    sources = sorted(Path("assets/anim/boss_vfx").iterdir())
    sources = [path for path in sources if path.is_dir()]
    assert len(sources) == 17, "Expected exactly the authored 17 VFX sets"
    report = {"sets": [], "aseprite_duration_ms": DURATIONS, "gif_duration_ms": GIF_DURATIONS}
    with (qa / "libresprite.log").open("w", encoding="utf-8") as log:
        def run(*arguments):
            result = subprocess.run([str(args.exe), "--batch", *map(str, arguments)],
                                    env=env, capture_output=True, timeout=45)
            log.write(result.stdout.decode("utf-8", errors="replace"))
            log.write(result.stderr.decode("utf-8", errors="replace"))
            log.flush()
            assert result.returncode == 0, (arguments, result.returncode)

        for source in sources:
            key = source.name
            assert {p.name for p in source.glob("*.png")} == {f"{i}.png" for i in range(12)}
            check = qa / key
            check.mkdir(exist_ok=True)
            ase = output / f"{key}.aseprite"
            gif = output / f"{key}.gif"
            run(source / "0.png", "--save-as", ase)
            set_ase_timing(ase)
            # Reopen through LibreSprite itself, then export PNGs and timing JSON.
            run(ase, "--save-as", check / "0.png", "--save-as", gif,
                "--format", "json-array", "--data", check / "frames.json",
                "--sheet-type", "horizontal", "--sheet", check / "sheet.png")
            metadata = json.loads((check / "frames.json").read_text(encoding="utf-8"))
            assert [frame["duration"] for frame in metadata["frames"]] == DURATIONS, key
            frame_hashes = []
            for index in range(12):
                original = rgba(source / f"{index}.png")
                assert original == rgba(check / f"{index}.png"), (key, index, "RGBA changed")
                frame_hashes.append(hashlib.sha256(original).hexdigest())
            set_gif_timing(gif)
            with Image.open(gif) as animation:
                assert animation.n_frames == 12, key
                actual_durations = []
                for index in range(12):
                    animation.seek(index)
                    actual_durations.append(animation.info["duration"])
                assert actual_durations == GIF_DURATIONS and sum(actual_durations) == 400
            # Reopening the final GIF in LibreSprite validates its metadata edit.
            run(gif, "--format", "json-array", "--data", check / "gif.json",
                "--sheet-type", "horizontal", "--sheet", check / "gif-sheet.png")
            gif_metadata = json.loads((check / "gif.json").read_text(encoding="utf-8"))
            assert [frame["duration"] for frame in gif_metadata["frames"]] == GIF_DURATIONS
            report["sets"].append({"key": key, "frames": 12, "duration_ms": 400,
                                   "rgba_sha256": frame_hashes, "source": str(ase), "preview": str(gif)})
            print(f"PASS {key}: 12 identical RGBA frames; ASE/GIF 400 ms", flush=True)
    report["verified_frames"] = sum(item["frames"] for item in report["sets"])
    (qa / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"Verified {len(report['sets'])} sets / {report['verified_frames']} frames", flush=True)


if __name__ == "__main__":
    main()
