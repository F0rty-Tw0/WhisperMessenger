import unittest

from scripts import gen_patch_notes


class RenderLuaTests(unittest.TestCase):
    def test_uses_fewer_escapes_for_mixed_quotes(self):
        line = 'Added a "?" button and a What\'s New page.'

        rendered = gen_patch_notes.render_lua("1.4.1", "2026-09-03", [line])

        self.assertIn("    'Added a \"?\" button and a What\\'s New page.',\n", rendered)

    def test_quote_lua_escapes_newline(self):
        self.assertEqual(gen_patch_notes.quote_lua("a\nb"), '"a\\nb"')


class ParseLatestSectionTests(unittest.TestCase):
    def test_nested_bullets_fold_into_parent_line(self):
        text = "## [1.5.0] - 2026-09-20\n- New look:\n  - Cleaner window.\n  - Softer colors.\n- Fixed: typo.\n"

        _version, _date, lines = gen_patch_notes.parse_latest_section(text)

        self.assertEqual(
            lines,
            ["New look:\n   - Cleaner window.\n   - Softer colors.", "Fixed: typo."],
        )


if __name__ == "__main__":
    unittest.main()
