#!/usr/bin/env bash
#
# Usage: bash scripts/release.sh <version>
# Example: bash scripts/release.sh 1.0.0
#
# Bumps the version in WhisperMessenger.toc and Core/Constants.lua,
# commits the change, creates an annotated git tag, and pushes it.
# The push triggers the GitHub Actions release workflow.

set -euo pipefail

VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
  echo "Usage: bash scripts/release.sh <version>"
  echo "Example: bash scripts/release.sh 1.0.0"
  exit 1
fi

# Validate semver-ish format (e.g. 1.0.0, 2.1.3)
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: Version must be in semver format (e.g. 1.0.0)"
  exit 1
fi

# Ensure working tree is clean
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Error: Working tree is not clean. Commit or stash changes first."
  exit 1
fi

# Ensure tag doesn't already exist
if git rev-parse "$VERSION" >/dev/null 2>&1; then
  echo "Error: Tag '$VERSION' already exists."
  exit 1
fi

echo "Releasing WhisperMessenger v${VERSION}..."

# Update version in TOC
sed -i "s/^## Version: .*/## Version: ${VERSION}/" WhisperMessenger.toc

# Update version in Constants.lua
sed -i "s/VERSION = \"[^\"]*\"/VERSION = \"${VERSION}\"/" Core/Constants.lua

# Commit version bump
git add WhisperMessenger.toc Core/Constants.lua
git commit -m "release: v${VERSION}"

# Create annotated tag
git tag -a "$VERSION" -m "Release ${VERSION}"

echo ""
echo "Version bumped and tag created."
echo ""
echo "To publish, push the tag:"
echo "  git push origin master ${VERSION}"
echo ""
echo "This will trigger the CI pipeline which:"
echo "  1. Runs lint checks"
echo "  2. Packages the addon"
echo "  3. Uploads to CurseForge"
echo "  4. Creates a GitHub Release"
