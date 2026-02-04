#!/bin/bash
# Manual fallback script - normally the GitHub Action handles this automatically
set -e

NEXT_VERSION=$1

if [ -z "$NEXT_VERSION" ]; then
  echo "Usage: ./scripts/post-release.sh <next-version>"
  echo "Example: ./scripts/post-release.sh 1.0.4-dev"
  exit 1
fi

# Switch to develop and sync with main
git checkout develop
git pull origin develop
git pull origin main

# Update version to next dev version
sed -i '' "s/version = \".*\"/version = \"$NEXT_VERSION\"/" Sources/VortexSDK/VortexSDK.swift

# Commit and push
git add -A
git commit -m "Bump version to $NEXT_VERSION for development"
git push origin develop

echo ""
echo "✅ develop is now at $NEXT_VERSION"
