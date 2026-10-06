#!/usr/bin/env python3
"""Flat BracketMate mark: a rounded knockout bracket on the app blue."""

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SIZE = 1024
BLUE = (47, 107, 255, 255)
WHITE = (255, 255, 255, 255)
GOLD = (255, 186, 46, 255)


def stamp(draw: ImageDraw.ImageDraw, points: list[tuple[float, float]], width: int) -> None:
    radius = width / 2
    for index in range(len(points) - 1):
        x0, y0 = points[index]
        x1, y1 = points[index + 1]
        dist = math.hypot(x1 - x0, y1 - y0)
        steps = max(1, int(dist / 1.4))
        for step in range(steps + 1):
            t = step / steps
            x = x0 + (x1 - x0) * t
            y = y0 + (y1 - y0) * t
            draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=WHITE)


def arc(cx: float, cy: float, radius: float, start: float, end: float, count: int = 28) -> list[tuple[float, float]]:
    points = []
    for index in range(count + 1):
        angle = math.radians(start + (end - start) * index / count)
        points.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
    return points


def draw_mark(canvas: Image.Image, scale: float = 1.0) -> None:
    def at(value: float) -> float:
        return SIZE / 2 + (value - SIZE / 2) * scale

    left = at(286)
    elbow = at(500)
    top = at(348)
    bottom = at(676)
    mid = (top + bottom) / 2
    turn = 74 * scale
    stroke = max(8, int(36 * scale))
    team = int(94 * scale)
    gold_outer = int(126 * scale)
    gold_x = at(728)

    draw = ImageDraw.Draw(canvas)
    top_arm = [(left, top), (elbow - turn, top)]
    top_arc = arc(elbow - turn, top + turn, turn, -90, 0)
    spine = [(elbow, top + turn), (elbow, bottom - turn)]
    bottom_arc = arc(elbow - turn, bottom - turn, turn, 0, 90)
    bottom_arm = [(elbow - turn, bottom), (left, bottom)]
    stem = [(elbow, mid), (gold_x, mid)]
    for part in (top_arm, top_arc, spine, bottom_arc, bottom_arm, stem):
        stamp(draw, part, stroke)

    hole = team - stroke + 6
    gold_inner = gold_outer - stroke + 6
    for cy in (top, bottom):
        draw.ellipse((left - team, cy - team, left + team, cy + team), fill=WHITE)
        draw.ellipse((left - hole, cy - hole, left + hole, cy + hole), fill=BLUE)
    draw.ellipse(
        (gold_x - gold_outer, mid - gold_outer, gold_x + gold_outer, mid + gold_outer),
        fill=WHITE,
    )
    draw.ellipse(
        (gold_x - gold_inner, mid - gold_inner, gold_x + gold_inner, mid + gold_inner),
        fill=GOLD,
    )


def main() -> None:
    logo = Image.new("RGBA", (SIZE, SIZE), BLUE)
    draw_mark(logo, scale=1.0)
    assets = ROOT / "assets"
    assets.mkdir(exist_ok=True)
    logo_path = assets / "logo.png"
    logo.convert("RGB").save(logo_path, optimize=True)

    splash = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(splash).ellipse((132, 132, 892, 892), fill=BLUE)
    draw_mark(splash, scale=0.78)
    splash_path = ROOT / "android/app/src/main/res/drawable-nodpi/splash_icon.png"
    splash_path.parent.mkdir(parents=True, exist_ok=True)
    splash.save(splash_path, optimize=True)
    print(f"wrote {logo_path}")
    print(f"wrote {splash_path}")


if __name__ == "__main__":
    main()
