import os
import struct
import tempfile
import unittest
import zlib

from scripts import compose_gold_ring


def png_info(data):
    """(width, height, bit depth, color type, raw scanlines) of a PNG."""
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    pos, ihdr, idat = 8, None, b""
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos : pos + 4])
        tag, body = data[pos + 4 : pos + 8], data[pos + 8 : pos + 8 + length]
        if tag == b"IHDR":
            ihdr = struct.unpack(">IIBB", body[:10])
        elif tag == b"IDAT":
            idat += body
        pos += 12 + length
    return ihdr + (zlib.decompress(idat),)


def render(write):
    with tempfile.TemporaryDirectory() as folder:
        path = os.path.join(folder, "art.png")
        write(path)
        with open(path, "rb") as handle:
            return handle.read()


def shipped(name):
    with open(os.path.join("Media", name), "rb") as handle:
        return handle.read()


class RingArtTests(unittest.TestCase):
    def test_shipped_ring_matches_the_generator(self):
        self.assertEqual(
            png_info(render(compose_gold_ring.write_ring)),
            png_info(shipped("ring_gold.png")),
        )

    def test_ring_is_256_square_rgba(self):
        self.assertEqual(png_info(shipped("ring_gold.png"))[:4], (256, 256, 8, 6))


if __name__ == "__main__":
    unittest.main()
