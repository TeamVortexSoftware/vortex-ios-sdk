#!/bin/bash
set -e

VERSION=$1
NEXT_VERSION=$2

if [ -z "$VERSION" ] || [ -z "$NEXT_VERSION" ]; then
  echo "Usage: ./scripts/release.sh <version> <next-dev-version>"
  echo "Example: ./scripts/release.sh 1.0.3 1.0.4-dev"
  exit 1
fi

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)

# 1. Work on develop — bump to release version
git checkout develop
git pull origin develop

sed -i '' "s/version = \".*\"/version = \"$VERSION\"/" Sources/VortexSDK/VortexSDK.swift
sed -i '' "s/from: \".*\"/from: \"$VERSION\"/" README.md
sed -i '' "s/Select version: .* or higher/Select version: \`$VERSION\` or higher/" README.md

git add -A
git commit -m "Release v$VERSION"
git push origin develop

# 2. Temporarily disable branch protection on main
echo "⏳ Disabling branch protection on main..."
gh api -X DELETE "repos/$REPO/branches/main/protection" 2>/dev/null || true

# 3. FF-only merge develop → main
git checkout main
git pull origin main
git merge --ff-only develop
git push origin main

# 4. Re-enable branch protection
echo "🔒 Re-enabling branch protection on main..."
gh api -X PUT "repos/$REPO/branches/main/protection" \
  --input - <<'EOF'
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1
  },
  "restrictions": null
}
EOF

# 5. Tag and release
git tag -a "$VERSION" -m "Release $VERSION"
git push origin "$VERSION"

gh release create "$VERSION" \
  --title "v$VERSION" \
  --generate-notes

# 6. Bump develop to next dev version
git checkout develop
sed -i '' "s/version = \".*\"/version = \"$NEXT_VERSION\"/" Sources/VortexSDK/VortexSDK.swift
git add -A
git commit -m "Bump version to $NEXT_VERSION for development"
git push origin develop

echo ""
echo "✅ Released v$VERSION"
echo "   - main and develop are in sync at release commit"
echo "   - Tag $VERSION created"
echo "   - GitHub Release created"
echo "   - Branch protection re-enabled"
echo "   - develop bumped to $NEXT_VERSION"
