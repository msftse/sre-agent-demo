import sys
from pathlib import Path

from PIL import Image, ImageDraw


def shield(size: int, *, background: str | None) -> Image.Image:
    image = Image.new("RGBA", (size, size), background or (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    scale = size / 192

    points = [
        (96 * scale, 22 * scale),
        (158 * scale, 48 * scale),
        (148 * scale, 123 * scale),
        (96 * scale, 169 * scale),
        (44 * scale, 123 * scale),
        (34 * scale, 48 * scale),
    ]
    outline = "#FFFFFF" if background is None else "#2DD4BF"
    width = max(2, round(10 * scale))
    draw.line(points + [points[0]], fill=outline, width=width, joint="curve")

    pulse = [
        (53 * scale, 98 * scale),
        (76 * scale, 98 * scale),
        (88 * scale, 72 * scale),
        (105 * scale, 124 * scale),
        (119 * scale, 98 * scale),
        (140 * scale, 98 * scale),
    ]
    pulse_color = "#FFFFFF" if background is None else "#FFB000"
    draw.line(pulse, fill=pulse_color, width=width, joint="curve")
    return image


def main() -> None:
    output = Path(sys.argv[1])
    output.mkdir(parents=True, exist_ok=True)
    shield(192, background="#0B1F33").save(output / "color.png")
    shield(32, background=None).save(output / "outline.png")


if __name__ == "__main__":
    main()