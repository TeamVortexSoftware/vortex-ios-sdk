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
    ├── Deletes release/1.0.3 branch
    └── Triggers bump-develop workflow
           │
           ▼
[GitHub Action: bump-develop.yml]
    ├── Merges main into develop
    ├── Updates VortexSDK.swift to 1.0.4-dev
    └── Creates PR to develop
           │
           ▼
Developer: Merges bump PR to develop
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

#### 4. Automatic Version Bump

The `bump-develop.yml` workflow automatically:
- Creates a PR to `develop` that bumps the version to `1.0.4-dev`
- Merges `main` into `develop` to sync the release commit

#### 5. Merge the Bump PR

- Review and merge the auto-created bump PR to `develop`
- Development continues on the new version

### Manual Fallback

If the automated bump fails, use the manual script:

```bash
./scripts/post-release.sh 1.0.4-dev
```

## Files Updated During Release

| File | What Changes |
|------|--------------|
| `Sources/VortexSDK/VortexSDK.swift` | `VortexSDKInfo.version` |
| `README.md` | Version in installation instructions |

## GitHub Actions

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `release.yml` | PR merged to `main` from `release/*` | Creates tag + GitHub Release |
| `bump-develop.yml` | Triggered by `release.yml` | Bumps develop to next `-dev` version |

## Troubleshooting

### PR creation fails

Ensure `gh` CLI is authenticated:
```bash
gh auth status
gh auth login
```

### Version bump PR not created

Check the GitHub Actions logs. You can manually run:
```bash
./scripts/post-release.sh X.Y.Z-dev
```

### Tag already exists

If re-releasing the same version, delete the existing tag first:
```bash
git push origin --delete 1.0.3
git tag -d 1.0.3
```
