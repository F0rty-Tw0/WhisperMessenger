#!/usr/bin/env python3
"""Turn CHANGELOG.md's [Unreleased] notes into a dated release section.

Usage:
    python scripts/promote_changelog.py --version v2.1.0
    python scripts/promote_changelog.py --version v2.1.0 --date 2026-09-25

- The [Unreleased] bullets move under a new '## [x.y.z] - <date>' heading and
  [Unreleased] is left empty for the next cycle.
- If [Unreleased] is empty and the top section already is this version (notes
  promoted by hand), nothing changes.
- A release that opens a new minor/major series moves the finished series
  into archive/changelog/<major>.<minor>.md and rebuilds the 'All releases:'
  nav line in every changelog file.
"""

import argparse
import datetime
import glob
import os
import re
import sys

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHANGELOG_PATH = os.path.join(PROJECT_ROOT, "CHANGELOG.md")
ARCHIVE_DIR = os.path.join(PROJECT_ROOT, "archive", "changelog")

UNRELEASED = "## [Unreleased]"
VERSION_HEADING = re.compile(r"^## \[(\d+)\.(\d+)\.\d+\]")
NAV_LINE = re.compile(r"(?m)^All releases: .*$")
SERIES_BLURB = re.compile(r"current \d+\.x series")
SEP = " · "


class ReleaseError(Exception):
    pass


def series_of(version):
    return ".".join(version.split(".")[:2])


def series_key(series):
    return tuple(int(part) for part in series.split("."))


def section_series(section):
    match = VERSION_HEADING.match(section)
    return "%s.%s" % match.groups() if match else None


def split_sections(text):
    """Return (preamble, [each '## ' section with its heading])."""
    chunks = re.split(r"(?m)^(?=## )", text)
    return chunks[0], chunks[1:]


def promote(text, version, date):
    preamble, sections = split_sections(text)
    if not sections or not sections[0].startswith(UNRELEASED):
        raise ReleaseError("CHANGELOG.md must have '%s' as its first section" % UNRELEASED)

    notes = sections[0][len(UNRELEASED) :].strip("\n")
    released = sections[1:]
    heading = "## [%s]" % version
    already_released = any(section.startswith(heading) for section in released)

    if not notes:
        if released and released[0].startswith(heading):
            return text
        raise ReleaseError("'%s' in CHANGELOG.md has no notes for v%s" % (UNRELEASED, version))
    if already_released:
        raise ReleaseError("CHANGELOG.md already has a '%s' section; move the new notes into it or pick a new version" % heading)

    new_section = "%s - %s\n\n%s\n\n" % (heading, date, notes)
    return preamble + UNRELEASED + "\n\n" + new_section + "".join(released)


def nav_line(current, all_series, this_series=None):
    """'All releases:' line for CHANGELOG.md (this_series=None) or one archive file."""
    parts = []
    for series in all_series:
        if series == current:
            parts.append("**%s.x (current)**" % series if this_series is None else "[%s.x (current)](../../CHANGELOG.md)" % series)
        elif series == this_series:
            parts.append("**%s.x (this file)**" % series)
        else:
            parts.append("[%s.x](%s%s.md)" % (series, "archive/changelog/" if this_series is None else "", series))
    return "All releases: " + SEP.join(parts)


def archive_header(series):
    return "# Changelog — %s.x\n\nArchived player-friendly release notes for WhisperMessenger %s.x.\n\nAll releases: \n\n" % (series, series)


def rotate_series(text, archives, current):
    """Move sections outside the current series into archives; rebuild nav lines."""
    preamble, sections = split_sections(text)
    kept = []
    moved = {}
    for section in sections:
        series = section_series(section)
        if series is None or series == current:
            kept.append(section)
        else:
            moved.setdefault(series, []).append(section)

    if not moved:
        return text, archives

    archives = dict(archives)
    for series, series_sections in moved.items():
        if series in archives:
            raise ReleaseError("archive/changelog/%s.md already exists; merge the %s.x notes by hand" % (series, series))
        body = "".join(series_sections).rstrip("\n") + "\n"
        archives[series] = archive_header(series) + body

    all_series = sorted(set(archives) | {current}, key=series_key, reverse=True)
    major = current.split(".")[0]
    preamble = SERIES_BLURB.sub("current %s.x series" % major, preamble)
    preamble = NAV_LINE.sub(lambda _m: nav_line(current, all_series), preamble, count=1)
    archives = {series: NAV_LINE.sub(lambda _m, s=series: nav_line(current, all_series, s), body, count=1) for series, body in archives.items()}
    return (preamble + "".join(kept)).rstrip("\n") + "\n", archives


def release_changelog(changelog, archives, version, date):
    """Pure core: return (new CHANGELOG.md text, {series: archive text})."""
    version = version.lstrip("v")
    promoted = promote(changelog, version, date)
    return rotate_series(promoted, archives, series_of(version))


def read(path):
    with open(path, "r", encoding="utf-8") as handle:
        return handle.read()


def write(path, text):
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)


def main():
    parser = argparse.ArgumentParser(description="Promote CHANGELOG.md [Unreleased] notes into a release section")
    parser.add_argument("--version", required=True, help="Release version (with or without a leading v)")
    parser.add_argument("--date", default=datetime.date.today().isoformat(), help="Release date (default: today)")
    args = parser.parse_args()

    changelog = read(CHANGELOG_PATH)
    archives = {os.path.splitext(os.path.basename(path))[0]: read(path) for path in glob.glob(os.path.join(ARCHIVE_DIR, "*.md"))}

    try:
        new_changelog, new_archives = release_changelog(changelog, archives, args.version, args.date)
    except ReleaseError as error:
        print("Error: %s" % error, file=sys.stderr)
        return 1

    if new_changelog == changelog:
        print("CHANGELOG.md already has v%s; nothing to promote" % args.version.lstrip("v"))
        return 0

    write(CHANGELOG_PATH, new_changelog)
    for series, text in new_archives.items():
        if archives.get(series) != text:
            write(os.path.join(ARCHIVE_DIR, "%s.md" % series), text)
    print("Promoted [Unreleased] to v%s in CHANGELOG.md" % args.version.lstrip("v"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
