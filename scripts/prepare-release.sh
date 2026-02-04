#!/bin/bash
set -e

VERSION=$1

if [ -z "$VERSION" ]; then
  echo "Usage: ./scripts/prepare-release.sh <version>"
  echo "Example: ./scripts/prepare-release.sh 1.0.3"
  exit 1
fi

# Ensure we're on develop and up to date
git checkout develop
git pull origin develop

# Create release branch
BRANCH="release/$VERSION"
git checkout -b "$BRANCH"

# Update version (only 2 files - single source of truth!)
sed -i '' "s/version = \".*\"/version = \"$VERSION\"/" Sources/VortexSDK/VortexSDK.swift
sed -i '' "s/from: \".*\"/from: \"$VERSION\"/" README.md
sed -i '' "s/Select version: .* or higher/Select version: \`$VERSION\` or higher/" README.md

# Commit and push
git add -A
git commit -m "Release v$VERSION"
git push -u origin "$BRANCH"

# Create PR using gh CLI
gh pr create \
  --base main \
  --head "$BRANCH" \
  --title "Release v$VERSION" \
  --body "## Release v$VERSION

This PR releases version $VERSION of VortexSDK.

### Checklist
- [ ] Version numbers updated
- [ ] CHANGELOG updated (if applicable)
- [ ] All tests passing

---
*After merging, GitHub Actions will automatically:*
1. *Create git tag and GitHub Release*
2. *Bump develop to next dev version*"

echo ""
echo "✅ Release PR created!"
echo "👉 Review and merge the PR. Everything else is automated!"
