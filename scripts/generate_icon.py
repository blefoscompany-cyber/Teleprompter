"""Regenerate the checked-in app icon. Pillow is a development-only tool."""
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
image = Image.new("RGB", (1024, 1024), (15, 19, 29))
draw = ImageDraw.Draw(image)
draw.rounded_rectangle((148, 220, 876, 805), radius=92, fill=(28, 35, 49), outline=(235, 240, 248), width=22)
draw.ellipse((436, 130, 588, 282), fill=(248, 70, 77))
for y, width in [(372, 500), (494, 500), (616, 356)]:
    draw.rounded_rectangle((250, y, 250 + width, y + 40), radius=20, fill=(235, 240, 248))
image.save(root / "Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
