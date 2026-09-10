"""Real Godot capture: native 60 fps MP4, plus a 20 fps GIF and contact sheet.

python tools/action_showcase.py after --capture
python tools/action_showcase.py after-dragon --capture --skin dragon --boss 10
python tools/action_showcase.py after  # assemble an existing 600-frame capture
Use the MP4 to judge motion; GIF timing and frame rate are less accurate.
"""
from pathlib import Path
import argparse
import os
import shutil
import subprocess
import uuid
from PIL import Image, ImageDraw

project = Path(__file__).resolve().parents[1]
root = project / "build" / "qa"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("tag", nargs="?", default="after")
parser.add_argument("--capture", action="store_true")
parser.add_argument("--skin", default="valentino_1")
parser.add_argument("--boss", type=int, default=0)
parser.add_argument("--orc", action="store_true", help="Run the authored Valentino/Orc combat study")
parser.add_argument("--foe", help="Run the same combat study with a FoeTiers actor key")
parser.add_argument("--pixel-motion-pilot", action="store_true", help="Enable the opt-in pixel motion pilot")
parser.add_argument("--skills", default="strike_rare,wave_epic,field_rare,ward_common",
                    help="One to four active skill keys, comma-separated")
parser.add_argument("--ffmpeg", help="Existing ffmpeg executable; PATH/local QA copy detected otherwise")
parser.add_argument("--godot", default="C:/Users/kpo02/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe")
args = parser.parse_args()
tag = args.tag
assert tag and all(c.isalnum() or c in "-_" for c in tag), "Tag must be a filename"
root.mkdir(parents=True, exist_ok=True)
ffmpeg = args.ffmpeg or shutil.which("ffmpeg")
if not ffmpeg:
    ffmpeg = next((str(p) for p in (root / "deps/imageio_ffmpeg/binaries").glob("ffmpeg*.exe")), None)
if not ffmpeg:
    try:
        import imageio_ffmpeg
        ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        parser.error("ffmpeg is required for MP4; provide an existing executable with --ffmpeg")
frame_dir = root / f"action-{tag}-frames"
if args.capture:
    profile = root / f"profile-{tag}-{uuid.uuid4().hex}"
    profile.mkdir()
    env = dict(os.environ, APPDATA=str(profile), LOCALAPPDATA=str(profile),
               BLOODLORD_CAPTURE_PROFILE=str(profile))
    # A failed new run must never be combined with an older capture's trailing frames.
    for old_frame in frame_dir.glob("[0-9][0-9][0-9][0-9].png"):
        old_frame.unlink()
    # CREATE_NO_WINDOW keeps the child console hidden on Windows.
    with (root / f"action-{tag}.log").open("w", encoding="utf-8") as log:
        process = subprocess.Popen([args.godot, "--path", str(project), "--fixed-fps", "60",
                        "--script", "tools/ActionShowcase.gd", "--",
                        f"--action-output=build/qa/action-{tag}",
                        f"--capture-skin={args.skin}", f"--capture-boss={args.boss}",
                        f"--capture-skills={args.skills}"] + (["--capture-orc"] if args.orc else [])
                        + ([f"--capture-foe={args.foe}"] if args.foe else [])
                        + (["--pixel-motion-pilot"] if args.pixel_motion_pilot else []),
                       cwd=project, env=env, stdout=log, stderr=subprocess.STDOUT,
                       creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
        (root / f"action-{tag}.pid").write_text(str(process.pid), encoding="ascii")
        try:
            result = process.wait(timeout=180)
        except subprocess.TimeoutExpired:
            # The Windows console launcher owns a renderer child: close our tree only.
            if os.name == "nt":
                subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                               capture_output=True, creationflags=subprocess.CREATE_NO_WINDOW)
            else:
                process.kill()
            process.wait()
            raise
        if result:
            raise subprocess.CalledProcessError(result, process.args)
paths = sorted(frame_dir.glob("*.png"))
assert [p.name for p in paths] == [f"{i:04d}.png" for i in range(600)], \
    f"Expected 600 consecutive native 60 fps frames, got {len(paths)}; recapture old 20 fps sequences"
mp4 = root / f"action-{tag}.mp4"
# Input timestamps come from real 60 fps renders: no duplication or interpolation.
subprocess.run([ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
                "-framerate", "60", "-start_number", "0", "-i", str(frame_dir / "%04d.png"),
                "-frames:v", "600", "-c:v", "libx264", "-preset", "fast", "-crf", "16",
                "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(mp4)],
               check=True, creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
# Keep the original compact GIF as a secondary preview; retain every third source frame.
frames = [Image.open(p).convert("RGB") for p in paths[::3]]
# One palette prevents forest colors from changing between frames and keeps GIF small.
samples = Image.new("RGB", (72 * 20, 40 * 10))
for i, frame in enumerate(frames):
    samples.paste(frame.resize((72, 40)), (i % 20 * 72, i // 20 * 40))
palette = samples.quantize(colors=256)
gif = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
gif[0].save(root / f"action-{tag}.gif", save_all=True, append_images=gif[1:],
            duration=50, loop=0, optimize=True)
selected = [12, 26, 45, 53, 73, 90, 106, 123, 139, 153, 173, 192]
sheet = Image.new("RGB", (576 * 3, 344 * 4), "#11111b")
draw = ImageDraw.Draw(sheet)
for cell, index in enumerate(selected):
    x, y = cell % 3 * 576, cell // 3 * 344
    sheet.paste(frames[index], (x, y + 24))
    draw.text((x + 12, y + 6), f"{tag.upper()}  {index / 20:.2f}s  |  60 FPS SOURCE", fill="#ddd6cf")
sheet.save(root / f"action-{tag}.png")
print(mp4)
print(root / f"action-{tag}.gif")
print(root / f"action-{tag}.png")
