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


class SquareFrameTests(unittest.TestCase):
    def alpha(self, x, y):
        return compose_gold_ring.square_pixel(x, y, 256)[3]

    def test_square_frame_leaves_a_one_pixel_margin(self):
        self.assertEqual(
            [self.alpha(0, 128), self.alpha(128, 0), self.alpha(255, 128), self.alpha(128, 255)],
            [0, 0, 0, 0],
        )
        self.assertEqual(self.alpha(1, 128), 1.0)

    def test_square_frame_has_square_corners(self):
        self.assertEqual(self.alpha(5, 5), 1.0)
        self.assertEqual(compose_gold_ring.ring_pixel(5, 5, 256)[3], 0.0)  # the ring is clear there

    def test_square_band_is_a_tenth_of_the_side(self):
        self.assertEqual(self.alpha(20, 128), 1.0)
        self.assertEqual(self.alpha(30, 128), 0.0)

    def test_square_hole_edge_is_smoothed_over_one_pixel(self):
        self.assertTrue(0 < self.alpha(26, 128) < 1)

    def test_square_hole_is_clear(self):
        self.assertEqual(self.alpha(128, 128), 0.0)

    def test_square_frame_is_lit_from_the_top_left(self):
        self.assertGreater(
            compose_gold_ring.square_pixel(10, 10, 256)[0],
            compose_gold_ring.square_pixel(245, 245, 256)[0],
        )

    def test_square_mode_writes_a_256_square_rgba_png(self):
        def write(path):
            self.assertEqual(compose_gold_ring.main(["--square", path]), 0)

        self.assertEqual(png_info(render(write))[:4], (256, 256, 8, 6))

    def test_shipped_square_frame_matches_the_generator(self):
        self.assertEqual(
            png_info(render(compose_gold_ring.write_square)),
            png_info(shipped("frame_gold_square.png")),
        )


class RoundedSquareArtTests(unittest.TestCase):
    def test_mask_is_clear_in_the_corner_and_opaque_in_the_centre(self):
        self.assertEqual(compose_gold_ring.square_mask_pixel(0, 0, 256)[3], 0.0)
        self.assertEqual(compose_gold_ring.square_mask_pixel(128, 128, 256)[3], 1.0)

    def test_glow_is_clear_in_the_centre(self):
        self.assertEqual(compose_gold_ring.square_glow_pixel(32, 32, 64)[3], 0.0)

    def test_glow_is_bright_just_inside_the_edge(self):
        alpha = compose_gold_ring.square_glow_pixel(32, 1, 64)[3]
        self.assertTrue(200 / 255 < alpha <= 1.0)

    def test_glow_has_faded_out_well_before_the_centre(self):
        self.assertEqual(compose_gold_ring.square_glow_pixel(32, 20, 64)[3], 0.0)

    def test_rounded_frame_is_clear_in_the_corner(self):
        self.assertEqual(compose_gold_ring.square_rounded_pixel(1, 1, 256)[3], 0.0)

    def test_rounded_frame_is_solid_just_inside_the_corner(self):
        self.assertGreater(compose_gold_ring.square_rounded_pixel(5, 5, 256)[3], 0.9)

    def test_rounded_frame_keeps_the_straight_edges(self):
        self.assertEqual(
            compose_gold_ring.square_rounded_pixel(128, 3, 256),
            compose_gold_ring.square_pixel(128, 3, 256),
        )

    def test_square_glow_mode_writes_a_64_square_rgba_png(self):
        def write(path):
            self.assertEqual(compose_gold_ring.main(["--square-glow", path]), 0)

        self.assertEqual(png_info(render(write))[:4], (64, 64, 8, 6))

    def test_square_mask_mode_writes_a_256_square_rgba_png(self):
        def write(path):
            self.assertEqual(compose_gold_ring.main(["--square-mask", path]), 0)

        self.assertEqual(png_info(render(write))[:4], (256, 256, 8, 6))

    def test_square_rounded_mode_writes_a_256_square_rgba_png(self):
        def write(path):
            self.assertEqual(compose_gold_ring.main(["--square-rounded", path]), 0)

        self.assertEqual(png_info(render(write))[:4], (256, 256, 8, 6))

    def test_shipped_square_glow_matches_the_generator(self):
        self.assertEqual(
            png_info(render(compose_gold_ring.write_square_glow)),
            png_info(shipped("inner-glow-square.png")),
        )

    def test_shipped_square_mask_matches_the_generator(self):
        self.assertEqual(
            png_info(render(compose_gold_ring.write_square_mask)),
            png_info(shipped("mask_rounded_square.png")),
        )

    def test_shipped_rounded_frame_matches_the_generator(self):
        self.assertEqual(
            png_info(render(compose_gold_ring.write_square_rounded)),
            png_info(shipped("frame_gold_square_rounded.png")),
        )


if __name__ == "__main__":
    unittest.main()
