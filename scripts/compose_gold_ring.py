"""Draws our gold ring as a transparent PNG, plus an in-context preview. Stdlib only.

Usage: python scripts/compose_gold_ring.py <ring.png> <preview.png>
       python scripts/compose_gold_ring.py --square <frame.png>
"""
import math
import struct
import sys
import zlib

SIZE = 256
INNER = 0.78  # hole edge as a share of the radius
LIGHT_STRENGTH = 0.22
SQUARE_BAND = 0.10  # frame band as a share of the side
# Band profile, outer edge (0) to hole edge (1): (position, red, green, blue).
PROFILE = [
    (0.00, 0.26, 0.17, 0.05),
    (0.10, 0.34, 0.23, 0.07),
    (0.24, 1.00, 0.87, 0.48),
    (0.42, 0.93, 0.72, 0.26),
    (0.78, 0.62, 0.43, 0.11),
    (0.92, 0.30, 0.20, 0.06),
    (1.00, 0.20, 0.13, 0.04),
]


def profile_color(t):
    t = max(0.0, min(1.0, t))
    for (p0, *c0), (p1, *c1) in zip(PROFILE, PROFILE[1:]):
        if t <= p1:
            k = (t - p0) / (p1 - p0)
            k = k * k * (3 - 2 * k)
            return [a + (b - a) * k for a, b in zip(c0, c1)]
    return list(PROFILE[-1][1:])


def clamp01(v):
    return max(0.0, min(1.0, v))


def ring_pixel(x, y, size):
    """RGBA floats for pixel center (x, y) in a size x size ring image."""
    radius = size / 2 - 1
    dx = x + 0.5 - size / 2
    dy = y + 0.5 - size / 2
    dist = math.hypot(dx, dy)
    r = dist / radius
    pixel = 1 / radius  # one pixel, in radius units, for edge smoothing
    alpha = clamp01((1 - r) / pixel + 0.5) * clamp01((r - INNER) / pixel + 0.5)
    color = apply_light(profile_color((1 - r) / (1 - INNER)), dx, dy)
    return color[0], color[1], color[2], alpha


def apply_light(color, dx, dy):
    """Light from the top left: dy grows downward in image rows."""
    dist = math.hypot(dx, dy)
    if dist == 0:
        return color
    light = 1 + LIGHT_STRENGTH * ((-dx - dy) / (dist * math.sqrt(2)))
    return [clamp01(c * light) for c in color]


def square_pixel(x, y, size):
    """RGBA floats for pixel center (x, y) in a size x size square frame image."""
    half = size / 2 - 1
    band = SQUARE_BAND * size
    dx = x + 0.5 - size / 2
    dy = y + 0.5 - size / 2
    d = max(abs(dx), abs(dy))
    alpha = clamp01(half - d + 0.5) * clamp01(d - (half - band) + 0.5)
    color = apply_light(profile_color((half - d) / band), dx, dy)
    return color[0], color[1], color[2], alpha


def write_png(path, width, height, rgba_rows):
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))

    raw = b"".join(b"\x00" + bytes(row) for row in rgba_rows)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as handle:
        handle.write(png)


def to_byte(value):
    return int(round(clamp01(value) * 255))


def write_art(path, pixel):
    rows = []
    for y in range(SIZE):
        row = []
        for x in range(SIZE):
            r, g, b, a = pixel(x, y, SIZE)
            row += [to_byte(r), to_byte(g), to_byte(b), to_byte(a)]
        rows.append(row)
    write_png(path, SIZE, SIZE, rows)


def write_ring(path):
    write_art(path, ring_pixel)


def write_square(path):
    write_art(path, square_pixel)


def write_preview(path, button=38, ring_scale=1.15, zoom=6, circle=(0.16, 0.14, 0.10)):
    """Button-sized render on the dark minimap color, zoomed so it can be judged."""
    backdrop = (0.08, 0.07, 0.05)
    canvas = button + 16
    samples = 4
    ring_side = button * ring_scale
    rows = []
    for py in range(canvas):
        row = []
        for px in range(canvas):
            total = [0.0, 0.0, 0.0]
            for sy in range(samples):
                for sx in range(samples):
                    x = px + (sx + 0.5) / samples - canvas / 2
                    y = py + (sy + 0.5) / samples - canvas / 2
                    rx = (x + ring_side / 2) * SIZE / ring_side
                    ry = (y + ring_side / 2) * SIZE / ring_side
                    cr, cg, cb, ca = ring_pixel(rx - 0.5, ry - 0.5, SIZE)
                    color = [backdrop[i] + (c - backdrop[i]) * ca for i, c in enumerate((cr, cg, cb))]
                    if math.hypot(x, y) <= button / 2:  # our opaque circle lies above the ring
                        color = list(circle)
                    for i in range(3):
                        total[i] += color[i]
            row.append([to_byte(t / samples**2) for t in total])
        rows.append(row)
    zoomed = []
    for row in rows:
        line = []
        for pixel in row:
            for _ in range(zoom):
                line += pixel + [255]
        zoomed += [line] * zoom
    write_png(path, canvas * zoom, canvas * zoom, zoomed)


def main(argv):
    if argv[:1] == ["--square"]:
        write_square(argv[1])
        return 0
    write_ring(argv[0])
    write_preview(argv[1])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
