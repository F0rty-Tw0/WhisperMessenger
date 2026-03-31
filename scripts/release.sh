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

# Update version in TOC
sed -i "s/^## Version: .*/## Version: ${TAG_VERSION}/" WhisperMessenger.toc

# Update version in Constants.lua
sed -i "s/VERSION = \"[^\"]*\"/VERSION = \"${TAG_VERSION}\"/" Core/Constants.lua

# Commit version bump
git add WhisperMessenger.toc Core/Constants.lua
git commit -m "release: ${TAG_VERSION}"

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