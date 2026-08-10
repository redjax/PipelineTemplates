# Go Versioned Release <!-- omit in toc -->

The [`go-versioned-release` workflow](../../../../../.forgejo/workflows/go-versioned-release.yml) orchestrates version detection, version bump pull requests, Go application builds, Git tags, Forgejo releases, and release asset uploads.

The workflow supports versioned and unversioned repositories. Versioned repositories release the contents of a configured version file after the version-bump pull request merges. Unversioned repositories use the current commit short SHA as the release version.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Example use](#example-use)

## Responsibilities

- Check-out the consuming repository.
- Check-out PipelineTemplates at the requested revision.
- Detect Go-related application changes.
- Detect changes to the configured version file.
- Decide whether to create a version-bump pull request.
- Decide whether to build and publish a release.
- Resolve the release version from an explicit override, commit short SHA, or version file.
- Create a version-bump branch and pull request when required.
- Build the application with go-build or GoReleaser.
- Package or collect release-ready assets.
- Create Git tags and Forgejo releases.
- Upload `.tar.gz`, `.zip`, checksums, packages, and other release assets.
- Remove a tag created for GoReleaser when the GoReleaser build fails.

## Inputs

- `versioned`: Whether the repository uses a version file and version-bump pull requests.
- `release-version`: Optional explicit release version override.
- `use-commit-sha`: Use the current commit short SHA when no explicit release version is provided.
- `force-release`: Release even when normal Go change detection finds no relevant files.
- `version-file`: Version file path relative to the repository root.
- `bumpversion-config`: Path to the bump-my-version configuration file.
- `bump-type`: Version bump type: `auto`, `major`, `minor`, or `patch`.
- `base-branch`: Base branch for version-bump pull requests.
- `tag-prefix`: Prefix prepended to semantic-version Git tags.
- `module-dir`: Path to the Go module root.
- `build-package`: Go package to build relative to `module-dir`.
- `binary-name`: Name of the built binary.
- `go-version`: Go version to install and use.
- `platforms`: Comma-separated `GOOS/GOARCH` targets for standard Go builds.
- `build-tags`: Optional Go build tags.
- `ldflags`: Optional linker flags passed to `go build`.
- `output-dir`: Build output directory.
- `use-goreleaser`: Use GoReleaser instead of the standard go-build action.
- `goreleaser-config`: Path to the GoReleaser configuration file.
- `goreleaser-version`: GoReleaser version to install and use.
- `change-paths`: Space-separated Go-related paths used for change detection.
- `pipelinetemplates-ref`: PipelineTemplates revision to check out.
- `forgejo-endpoint`: Forgejo API endpoint.
- `repository`: Repository in `owner/name` form.
- `FJ_TOKEN`: Forgejo token used to create pull requests, tags, releases, and release assets.

## Example use

A versioned Go application normally calls this workflow after pushes to its release branch:

```yaml
---
name: Release

on:
  push:
    branches:
      - main

jobs:
  release:
    uses: redjax/PipelineTemplates/.forgejo/workflows/go-versioned-release.yml@main
    with:
      versioned: true
      release-version: ""
      use-commit-sha: false
      force-release: false

      version-file: ".version"
      bumpversion-config: ".bumpversion.toml"
      bump-type: auto
      base-branch: main

      tag-prefix: v

      module-dir: "."
      build-package: "./cmd/api"
      binary-name: pizerow-api
      go-version: "1.26.4"
      platforms: linux/amd64
      output-dir: dist

      use-goreleaser: false
      goreleaser-config: ".goreleaser.yml"
      goreleaser-version: latest

      change-paths: "go.mod go.sum cmd internal pkg"

      pipelinetemplates-ref: main
      forgejo-endpoint: ${{ github.server_url }}/api/v1
      repository: ${{ github.repository }}
    secrets:
      FJ_TOKEN: ${{ secrets.FJ_TOKEN }}
```

An unversioned repository can release directly from a commit SHA:

```yaml
jobs:
  release:
    uses: redjax/PipelineTemplates/.forgejo/workflows/go-versioned-release.yml@main
    with:
      versioned: false
      use-commit-sha: true
      force-release: false
      tag-prefix: ""
      module-dir: "."
      build-package: "./cmd/api"
      binary-name: example-api
      go-version: "1.26.4"
      platforms: linux/amd64
      output-dir: dist
      use-goreleaser: false
      change-paths: "go.mod go.sum cmd internal pkg"
      pipelinetemplates-ref: main
      forgejo-endpoint: ${{ github.server_url }}/api/v1
      repository: ${{ github.repository }}
    secrets:
      FJ_TOKEN: ${{ secrets.FJ_TOKEN }}
```
