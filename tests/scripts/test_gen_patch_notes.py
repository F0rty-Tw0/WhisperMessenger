import unittest

from scripts import gen_patch_notes


class RenderLuaTests(unittest.TestCase):
    def test_uses_fewer_escapes_for_mixed_quotes(self):
        line = 'Added a "?" button and a What\'s New page.'

        rendered = gen_patch_notes.render_lua("1.4.1", "2026-09-03", [line])

        self.assertIn("    'Added a \"?\" button and a What\\'s New page.',\n", rendered)


if __name__ == "__main__":
    unittest.main()
