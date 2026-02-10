# Contributing to Vortex iOS SDK

This document covers development workflows and release processes for the Vortex iOS SDK.

## Development Setup

### Prerequisites

- Xcode 14.0+
- Swift 5.9+
- `gh` CLI installed and authenticated (`brew install gh && gh auth login`)

### Building

```bash
xcodebuild -scheme VortexSDK -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## Version Management

### Single Source of Truth

The SDK version is defined in **one place**:

```
Sources/VortexSDK/VortexSDK.swift → VortexSDKInfo.version
```

`VortexClient.swift` references `VortexSDKInfo.version` automatically.

### Version Format

- **develop branch**: `X.Y.Z-dev` (e.g., `1.0.4-dev`)
- **main branch / releases**: `X.Y.Z` (e.g., `1.0.3`)

## Release Process

### Overview

```
Developer: ./scripts/release.sh 1.0.3 1.0.4-dev
    │
    ├── Bumps version to 1.0.3 on develop
    ├── FF-only merges develop → main
    ├── Creates git tag 1.0.3
    ├── Creates GitHub Release with auto-generated notes
    └── Bumps develop to 1.0.4-dev
```

### Step-by-Step

From the `develop` branch, run:

```bash
./scripts/release.sh 1.0.3 1.0.4-dev
```

This single script:
1. Bumps the version to `1.0.3` on `develop` and pushes
2. Temporarily disables branch protection on `main`
3. Fast-forward merges `develop` into `main` (preserving commit SHAs)
4. Re-enables branch protection on `main`
5. Creates a git tag and GitHub Release
6. Bumps `develop` to `1.0.4-dev` and pushes

## Files Updated During Release

| File | What Changes |
|------|--------------|
| `Sources/VortexSDK/VortexSDK.swift` | `VortexSDKInfo.version` |
| `README.md` | Version in installation instructions |

## Troubleshooting

### `gh` CLI not authenticated

Ensure `gh` CLI is authenticated:
```bash
gh auth status
gh auth login
```

### Tag already exists

If re-releasing the same version, delete the existing tag first:
```bash
git push origin --delete 1.0.3
git tag -d 1.0.3
```
