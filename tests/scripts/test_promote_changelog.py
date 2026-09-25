import unittest

from scripts import promote_changelog

NAV_2_0 = "All releases: **2.0.x (current)** · [1.4.x](archive/changelog/1.4.md)"

CHANGELOG = (
    "# Changelog\n"
    "\n"
    "Player-friendly release notes for WhisperMessenger. This file covers the current 2.x series; "
    "older series live in [archive/changelog/](archive/changelog/).\n"
    "\n" + NAV_2_0 + "\n"
    "\n"
    "## [Unreleased]\n"
    "\n"
    "- New thing.\n"
    "  - Detail.\n"
    "- Fixed: old thing.\n"
    "\n"
    "## [2.0.0] - 2026-09-23\n"
    "\n"
    "- Big release.\n"
)

ARCHIVE_1_4 = (
    "# Changelog — 1.4.x\n"
    "\n"
    "Archived player-friendly release notes for WhisperMessenger 1.4.x.\n"
    "\n"
    "All releases: [2.0.x (current)](../../CHANGELOG.md) · **1.4.x (this file)**\n"
    "\n"
    "## [1.4.3] - 2026-09-18\n"
    "\n"
    "- Old release.\n"
)


def release(version, changelog=CHANGELOG, archives=None):
    archives = {"1.4": ARCHIVE_1_4} if archives is None else archives
    return promote_changelog.release_changelog(changelog, archives, version, "2026-09-25")


class PromoteTests(unittest.TestCase):
    def test_unreleased_notes_move_under_a_dated_version_heading(self):
        changelog, _archives = release("2.0.1")

        self.assertIn(
            "## [Unreleased]\n\n## [2.0.1] - 2026-09-25\n\n- New thing.\n  - Detail.\n- Fixed: old thing.\n\n## [2.0.0] - 2026-09-23\n",
            changelog,
        )

    def test_patch_release_leaves_archives_untouched(self):
        _changelog, archives = release("2.0.1")

        self.assertEqual(archives, {"1.4": ARCHIVE_1_4})

    def test_already_promoted_version_is_a_no_op(self):
        promoted, archives = release("2.0.1")

        again, again_archives = release("2.0.1", changelog=promoted, archives=archives)

        self.assertEqual(again, promoted)
        self.assertEqual(again_archives, archives)

    def test_empty_unreleased_for_a_new_version_is_an_error(self):
        promoted, _archives = release("2.0.1")

        with self.assertRaises(promote_changelog.ReleaseError):
            release("2.0.2", changelog=promoted)

    def test_existing_version_heading_with_new_notes_is_an_error(self):
        with self.assertRaises(promote_changelog.ReleaseError):
            release("2.0.0")


class NewSeriesTests(unittest.TestCase):
    def test_new_minor_archives_the_finished_series(self):
        changelog, archives = release("2.1.0")

        self.assertNotIn("## [2.0.0]", changelog)
        self.assertTrue(changelog.endswith("- Fixed: old thing.\n"), "changelog should end with a single newline")
        self.assertEqual(
            archives["2.0"],
            "# Changelog — 2.0.x\n"
            "\n"
            "Archived player-friendly release notes for WhisperMessenger 2.0.x.\n"
            "\n"
            "All releases: [2.1.x (current)](../../CHANGELOG.md) · **2.0.x (this file)** · [1.4.x](1.4.md)\n"
            "\n"
            "## [2.0.0] - 2026-09-23\n"
            "\n"
            "- Big release.\n",
        )

    def test_new_minor_rebuilds_every_nav_line(self):
        changelog, archives = release("2.1.0")

        self.assertIn(
            "All releases: **2.1.x (current)** · [2.0.x](archive/changelog/2.0.md) · [1.4.x](archive/changelog/1.4.md)\n",
            changelog,
        )
        self.assertIn(
            "All releases: [2.1.x (current)](../../CHANGELOG.md) · [2.0.x](2.0.md) · **1.4.x (this file)**\n",
            archives["1.4"],
        )

    def test_new_major_updates_the_series_blurb(self):
        changelog, _archives = release("3.0.0")

        self.assertIn("This file covers the current 3.x series;", changelog)


if __name__ == "__main__":
    unittest.main()
