"""Package existing mascot poses as a lossless Android loading animation.

Requires Pillow with animated WebP support. The source PNG artwork is unchanged.
"""
from pathlib import Path
from PIL import Image

mobile = Path(__file__).resolve().parents[1]
source = mobile / "assets/images/scenery/backgrounds/start-assets/mascot"
destination = mobile / "android/app/src/main/res/drawable-nodpi/start_mascot_loading.webp"
frames = []
for pose in ("idle", "happy"):
    with Image.open(source / f"{pose}.png") as image:
        frame = image.convert("RGBA")
        if pose == "idle":
            # The shared animation draws at 1.16; idle should appear at 1.067.
            # Center the slightly smaller pose inside the original 1254px canvas.
            smaller = frame.resize(
                tuple(round(value * 1.067 / 1.16) for value in frame.size),
                Image.Resampling.LANCZOS,
            )
            canvas = Image.new("RGBA", frame.size)
            canvas.alpha_composite(smaller,
                ((frame.width - smaller.width) // 2,
                 (frame.height - smaller.height) // 2))
            frame = canvas
        # Keep full-resolution, lossless frames; do not halve animation detail.
        frames.append(frame)
destination.parent.mkdir(parents=True, exist_ok=True)
frames[0].save(destination, save_all=True, append_images=frames[1:],
               duration=[600] * len(frames), loop=0, lossless=True, method=6)
print(f"{destination.name}: {destination.stat().st_size} bytes")
