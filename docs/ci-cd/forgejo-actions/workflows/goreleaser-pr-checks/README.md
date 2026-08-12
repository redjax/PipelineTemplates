# GoReleaser PR Checks <!-- omit in toc -->

The goreleaser-pr-checks workflow validates that a Go project can successfully build using GoReleaser before changes are merged.

The workflow runs GoReleaser in snapshot mode, producing build artifacts without publishing releases. It is intended to catch build configuration errors, invalid GoReleaser configuration, and release packaging failures during pull requests.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Example use](#example-use)

## Responsibilities

- Check-out the consuming repository.
- Check-out PipelineTemplates actions required for Forgejo compatibility.
- Detect whether GoReleaser-related files changed.
- Install and configure the requested Go version.
- Install the requested GoReleaser version.
- Validate the .goreleaser.yml configuration.
- Run a GoReleaser snapshot build.
- Upload generated artifacts when enabled.
- Fail the PR if the release build cannot complete successfully.

## Inputs

- `change-paths`: JSON list of file patterns that trigger GoReleaser validation.
- `module-dir`: Directory containing the Go module and GoReleaser configuration.
- `go-version`: Go version to install and use for the build.
- `goreleaser-version`: GoReleaser version to install.
- `snapshot`: Run GoReleaser in snapshot mode without publishing.
- `upload-artifacts`: Upload generated build artifacts.
- `enable-cache`: Enable Go module and build caching.
- `base-sha`: Base commit SHA used for change detection.
- `head-sha`: Head commit SHA used for change detection.
- `pipelinetemplates-ref`: PipelineTemplates branch or tag containing the reusable GoReleaser action.

## Example use

This workflow is usually called from a PR validation pipeline:

```yaml
---
name: GoReleaser PR Checks

on:
  pull_request:
    branches:
      - main
    types:
      - opened
      - synchronize
      - reopened

permissions:
  contents: read

jobs:
  goreleaser:
    uses: redjax/PipelineTemplates/.forgejo/workflows/goreleaser-pr-checks.yml@main
    with:
      base-sha: ${{ github.event.pull_request.base.sha }}
      head-sha: ${{ github.event.pull_request.head.sha }}
      go-version: "1.26.4"
      goreleaser-version: "2.17.1"
      snapshot: true
      upload-artifacts: true
      enable-cache: true
      pipelinetemplates-ref: main
```
