# Releasing

Releases in this repository are managed with release-please.

## Overview

`release-please` has a two-phase process:

1. **Phase 1**: It looks for conventional commits. When it detects a *releasable unit*, it creates or updates a release PR with version updates and release notes.
2. **Phase 2**: When that PR is merged, `release-please` creates tags, labels, releases, etc. This also triggers custom steps like publishing packages and documentation.

---

## What is a Releasable Unit?

Using semver:
- **Breaking changes** → bump major version
- **New features (backward compatible)** → bump minor version
- **Bug fixes (backward compatible)** → bump patch version

> Not all changes require a new release (e.g. updating a build script).

A commit that starts with `chore:` is not a releasable unit. If only non-releasable commits are present, no release is created.

---

## Conventional Commit Tags

### Releasable

| Tag     | Version Change            | Description                                  |
|---------|---------------------------|----------------------------------------------|
| `fix:`  | `1.0.0 → 1.0.1`           | Backward compatible bug fix                  |
| `feat:` | `1.0.0 → 1.1.0`           | New feature (backward compatible), deprecations |
| `feat!` | `1.0.0 → 2.0.0`           | Breaking feature addition                    |
| `fix!`  | `1.0.0 → 2.0.0`           | Breaking bug fix                             |

### Non-releasable

| Tag       | Description                                            |
|-----------|--------------------------------------------------------|
| `chore:`  | General non-releasable changes                         |
| `ci:`     | CI configuration changes                               |
| `docs:`   | Documentation updates                                  |
| `style:`  | Code formatting changes                                |
| `refactor:` | Code refactors (can be releasable depending on context) |
| `test:`   | Test updates                                           |

---

## Corrections

You can override a commit message by editing the PR description **before or after it’s merged**:

```
BEGIN_COMMIT_OVERRIDE
fix: This is my new message and conventional commit tag!
END_COMMIT_OVERRIDE
```

If post-merge, then the release-please workflow will need re-ran. Re-running the workflow will update the release PR.

---

## Release Affecting a Shared Package

This repo cannot automatically update inter-package dependencies and release those packages. Instead each package must be released in dependency order while making sure to update inter-package dependencies between releases.

For example imagine that the `launchdarkly_dart_common` is currently at version `1.5.0`.

If we merge a PR `feat: Add the new thing` which only affects files in `packages/common`, then release-please will determine it needs to release `1.6.0`. Release please will create a release PR and when we merge that release PR it will release `1.6.0` of `launchdarkly_dart_common`.

No end-user is going to receive this package when they install `launchdarkly_flutter_client_sdk`, because that will be pinned to a specific version of `launchdarkly_common_client` which uses a pinned version of `launchdarkly_dart_common`.

So we need to first edit the pubspec of `launchdarkly_common_client` to use `launchdarkly_dart_common` version `1.6.0`.

In order to do this we would create and merge a new PR titles `feat: Update launchdarkly_dart_common to version 1.6.0`.

We would merge that PR, then release `launchdarkly_common_client`. We continue to do this until all affected packages are released.

### PR Affecting Multiple Packages

If a single PR affects multiple packages, then the individual packages still must be released in dependency order updating affected versions between releases.

For example imagine that the `launchdarkly_dart_common` is currently at version `1.5.0`, `launchdarkly_client_common` is version `1.6.0` and `launchdarkly_flutter_client_sdk` is `4.10.0`.

If we merge a PR `feat: Add the new thing` which affects files in `packages/common` and `packages/flutter_client_sdk`, then release-please will determine it needs to release `1.6.0` of `launchdarkly_dart_common` and `4.11.0` of `launchdarkly_flutter_client_sdk`. Release please is going to create release PRs for *BOTH* of these packages.

In order to fully release this update we actually will need to release `launchdarkly_dart_common`, `launchdarkly_common_client`, and `launchdarkly_flutter_client_sdk`.

What we would do is this:
- Merge the release PR for `launchdarkly_dart_common`.
- Create and then merge a new PR for `launchdarkly_common_client` which updates it to use `1.6.0` of `launchdarkly_dart_common`. This will generate a new release PR for `launchdarkly_common_client` version `1.7.0`
- Merge the release PR for `launchdarkly_common_client`.
- Create and then merge a new PR for `launchdarkly_flutter_client_sdk` which updates it to use `1.7.0` of `launchdarkly_dart_common`. This will update the release PR for `launchdarkly_common_client` version `4.11.0`
- Merge the release PR for `launchdarkly_flutter_client_sdk`.
