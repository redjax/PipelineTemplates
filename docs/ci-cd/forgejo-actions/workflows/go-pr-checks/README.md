# Go PR Checks <!-- omit in toc -->

The go-pr-checks workflow validates Go changes in a pull request by detecting Go-related file changes, setting up the requested Go toolchain, and running a Go build validation.

The workflow is designed for PR validation only. It does not publish artifacts, create releases, or modify repository state.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Example use](#example-use)

## Responsibilities

- Check-out the consuming repository.
- Detect whether Go-related files changed.
- Install and configure the requested Go version.
- Restore and manage Go build cache (if enabled).
- Run Go build validation.
- Fail the PR if the project cannot compile successfully.

## Inputs

- `change-paths`: JSON list of file patterns that trigger Go validation.
- `go-version`: Go version to install and use for the build.
- `enable-cache`: Enable Go module and build caching.
- `base-sha`: Base commit SHA used for change detection.
- `head-sha`: Head commit SHA used for change detection.
- `runner-image`: Runner label or image to use.

## Example use

This workflow is typically called directly from a PR validation pipeline:

```yaml
---
name: Go PR Checks

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
  go-build:
    uses: redjax/PipelineTemplates/.forgejo/workflows/go-pr-checks.yml@main
    with:
      base-sha: ${{ github.event.pull_request.base.sha }}
      head-sha: ${{ github.event.pull_request.head.sha }}
      go-version: "1.26.4"
      enable-cache: true
      runner-image: forgejo-runner-base
```
