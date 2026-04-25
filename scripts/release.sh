#!/usr/bin/env bash
#
# Usage: bash scripts/release.sh <version>
# Example: bash scripts/release.sh 1.0.0
##
## Accepts 1.0.0 or v1.0.0 and always normalizes to v-prefixed
## tags and file versions.

set -euo pipefail

INPUT_VERSION="${1:-}"

if [[ -z "$INPUT_VERSION" ]]; then
  echo "Usage: bash scripts/release.sh <version>"
  echo "Example: bash scripts/release.sh 1.0.0"
  exit 1
fi

if ! [[ "$INPUT_VERSION" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: Version must be semver (e.g. 1.0.0 or v1.0.0)"
  exit 1
fi

NORMALIZED_VERSION="${INPUT_VERSION#v}"
TAG_VERSION="v${NORMALIZED_VERSION}"

# Ensure working tree is clean
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Error: Working tree is not clean. Commit or stash changes first."
  exit 1
fi

# Ensure tag doesn't already exist
if git show-ref --verify --quiet "refs/tags/${TAG_VERSION}"; then
  echo "Error: Tag '${TAG_VERSION}' already exists."
  exit 1
fi

echo "Releasing WhisperMessenger ${TAG_VERSION}..."

# Fetch live TOC interface numbers from Blizzard's patch CDN, one per flavor
# product. Refuses to release if any required product is unreachable so we
# never ship a stale interface after a WoW patch. TBC and Cata Classic are
# EOL — Blizzard no longer publishes a live `wow_tbc` or `wow_classic_cata`
# product, so those lines are left at whatever the TOC currently has.
fetch_toc() {
  local product="$1"
  python -c "
import re, sys, urllib.request
try:
    with urllib.request.urlopen('https://us.version.battle.net/v2/products/${product}/versions', timeout=15) as r:
        text = r.read().decode('utf-8', errors='replace')
except Exception as e:
    sys.stderr.write('fetch failed for ${product}: ' + str(e) + '\n')
    sys.exit(1)
for line in text.splitlines():
    if line.startswith('us|'):
        m = re.search(r'\b(\d+)\.(\d+)\.(\d+)\.\d+\b', line)
        if m:
            a, b, c = m.groups()
            print(f'{int(a)}{int(b):02d}{int(c):02d}')
            break
"
}

cdn_die() {
  echo "Error: could not reach https://us.version.battle.net/ for product '$1'."
  echo "       Fix network and retry, or release via GitHub Actions."
  exit 1
}

echo "Fetching live TOC interface numbers from Blizzard CDN..."
TOC_RETAIL=$(fetch_toc wow) || cdn_die wow
TOC_VANILLA=$(fetch_toc wow_classic_era) || cdn_die wow_classic_era
TOC_MISTS=$(fetch_toc wow_classic) || cdn_die wow_classic

if [[ -z "$TOC_RETAIL" || -z "$TOC_VANILLA" || -z "$TOC_MISTS" ]]; then
  echo "Error: could not parse one or more TOC numbers from Blizzard response."
  echo "       retail='${TOC_RETAIL}' vanilla='${TOC_VANILLA}' mists='${TOC_MISTS}'"
  exit 1
fi

echo "  retail (Mainline): ${TOC_RETAIL}"
echo "  vanilla:           ${TOC_VANILLA}"
echo "  mists:             ${TOC_MISTS}"
echo "  TBC and Cata: skipped (Classic seasons EOL, no live CDN)"

sed -i "s/^## Interface: .*/## Interface: ${TOC_RETAIL}/" WhisperMessenger.toc
sed -i "s/^## Interface-Mainline: .*/## Interface-Mainline: ${TOC_RETAIL}/" WhisperMessenger.toc
sed -i "s/^## Interface-Vanilla: .*/## Interface-Vanilla: ${TOC_VANILLA}/" WhisperMessenger.toc
sed -i "s/^## Interface-Mists: .*/## Interface-Mists: ${TOC_MISTS}/" WhisperMessenger.toc

# Update version in TOC
sed -i "s/^## Version: .*/## Version: ${TAG_VERSION}/" WhisperMessenger.toc

# Update version in Constants.lua
sed -i "s/VERSION = \"[^\"]*\"/VERSION = \"${TAG_VERSION}\"/" Core/Constants.lua

# Commit version + interface bump
git add WhisperMessenger.toc Core/Constants.lua
if git diff --cached --quiet; then
  echo "No TOC or version changes to commit (already up to date)."
else
  git commit -m "release: ${TAG_VERSION}"
fi

# Create annotated tag
git tag -a "${TAG_VERSION}" -m "Release ${TAG_VERSION}"

echo ""
echo "Version bumped and tag created."
echo ""
echo "To publish, push the tag:"
echo "  git push origin master ${TAG_VERSION}"
echo ""
echo "This will trigger the CI pipeline which:"
echo "  1. Runs lint checks"
echo "  2. Packages the addon"
echo "  3. Uploads to CurseForge"
echo "  4. Creates a GitHub Release"
