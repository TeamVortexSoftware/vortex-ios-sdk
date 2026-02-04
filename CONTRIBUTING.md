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
Developer: ./scripts/prepare-release.sh 1.0.3
    │
    ▼
[Branch release/1.0.3 created + PR opened]
    │
    ▼
Developer: Reviews & merges PR to main
    │
    ▼
[GitHub Action: release.yml]
    ├── Creates git tag 1.0.3
    ├── Creates GitHub Release with auto-generated notes
    └── Deletes release/1.0.3 branch
           │
           ▼
Developer: ./scripts/post-release.sh 1.0.4-dev
    └── Bumps develop to next -dev version
```

### Step-by-Step

#### 1. Prepare the Release

From the `develop` branch:

```bash
./scripts/prepare-release.sh 1.0.3
```

This script:
- Creates a `release/1.0.3` branch
- Updates `VortexSDK.swift` version to `1.0.3` (removes `-dev`)
- Updates `README.md` with the new version
- Commits and pushes the branch
- Creates a PR to `main` via `gh` CLI

#### 2. Review and Merge

- Review the PR in GitHub
- Ensure CI passes
- Merge the PR to `main`

#### 3. Automatic Release (GitHub Actions)

After merging, the `release.yml` workflow automatically:
- Creates a git tag (e.g., `1.0.3`)
- Creates a GitHub Release with auto-generated release notes
- Deletes the `release/1.0.3` branch

#### 4. Bump Develop Version

After the release is created, bump develop to the next version:

```bash
./scripts/post-release.sh 1.0.4-dev
```

This script:
- Switches to `develop` and syncs with `main`
- Updates `VortexSDK.swift` to the next `-dev` version
- Commits and pushes to `develop`

## Files Updated During Release

| File | What Changes |
|------|--------------|
| `Sources/VortexSDK/VortexSDK.swift` | `VortexSDKInfo.version` |
| `README.md` | Version in installation instructions |

## GitHub Actions

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `release.yml` | PR merged to `main` from `release/*` | Creates tag + GitHub Release |

## Troubleshooting

### PR creation fails

Ensure `gh` CLI is authenticated:
```bash
gh auth status
gh auth login
```

### Forgot to bump develop

After a release, run:
```bash
./scripts/post-release.sh X.Y.Z-dev
```

### Tag already exists

If re-releasing the same version, delete the existing tag first:
```bash
git push origin --delete 1.0.3
git tag -d 1.0.3
```
