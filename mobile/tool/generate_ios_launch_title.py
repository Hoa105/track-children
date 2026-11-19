"""Generate the iOS-only static title from the Flutter Start font (Pillow)."""

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def main():
    mobile = Path(__file__).resolve().parents[1]
    destination = mobile / "ios/Runner/Assets.xcassets/StartTitle.imageset"
    destination.mkdir(parents=True, exist_ok=True)
    font_path = mobile / "assets/fonts/nunito/Nunito-Variable.ttf"
    title = "B\u00e9 l\u1edbn kh\u00f4n"
    font = ImageFont.truetype(str(font_path), 120)
    font.set_variation_by_axes([900])
    width = math.ceil(font.getlength(title) / 3)
    entries = []
    for scale in (1, 2, 3):
        font = ImageFont.truetype(str(font_path), 40 * scale)
        font.set_variation_by_axes([900])
        image = Image.new("RGBA", (width * scale, 48 * scale))
        ascent, descent = font.getmetrics()
        baseline = (48 * scale - ascent - descent) / 2 + ascent
        ImageDraw.Draw(image).text(
            (width * scale / 2, baseline), title, font=font,
            fill="#29451E", anchor="ms",
        )
        filename = f"start_title@{scale}x.png"
        image.save(destination / filename)
        entries.append({"filename": filename, "idiom": "universal", "scale": f"{scale}x"})
    (destination / "Contents.json").write_text(
        json.dumps({"images": entries, "info": {"author": "xcode", "version": 1}}, indent=2)
        + "\n", encoding="utf-8",
    )
    print(f"Title size: {width} x 48 points")


if __name__ == "__main__":
    main()
