# Merge Version Bump PR <!-- omit in toc -->

The [`merge-version-bump` workflow](../../../../../.forgejo/workflows/merge-version-bump.yml) merges a previously created version-bump pull request into its target branch after the consuming repository’s pull-request CI checks have succeeded.

> [!NOTE]
> Forgejo does not provide GitHub-style repository auto-merge in this pipeline. Instead, the consuming repository calls this reusable workflow as the final job in its PR-check workflow.
>
> The workflow squash-merges the version-bump PR and deletes its source branch.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Example use](#example-use)
- [Expected pipeline flow](#expected-pipeline-flow)

## Responsibilities

- Receive the pull request number created by the `version-bump` pipeline.
- Authenticate to the consuming repository’s Forgejo API.
- Squash-merge the `version-bump` pull request.
- Delete the `version-bump` source branch after a successful merge.
- Fail without merging when the Forgejo API rejects the merge request.

This workflow does not create a version bump, run application tests, build binaries, create tags, or create Forgejo releases. It should run only after the consuming repository’s required PR CI jobs succeed.

## Inputs

- `pr-number`: Pull request number to merge.
- `forgejo-endpoint`: Forgejo API endpoint ending in `/api/v1`.
- `repository`: Repository in `owner/name` form.
- `FJ_TOKEN`: Forgejo token authorized to merge pull requests into the target branch.

## Example use

Call this workflow as a dependent job at the end of the consuming repository’s existing pull-request CI workflow, i.e. in a `pr-checks.yml` pipeline:

```yaml
---
name: PR Checks

on:
  pull_request:
    branches:
      - main
    types:
      - opened
      - synchronize
      - reopened

jobs:
  go-pr-checks:
    uses: redjax/PipelineTemplates/.forgejo/workflows/go-pr-checks.yml@main
    with:
      base-sha: ${{ github.event.pull_request.base.sha || github.event.before }}
      head-sha: ${{ github.event.pull_request.head.sha || github.sha }}
      module-dir: .
      build-package: ./cmd/api
      binary-name: example-api
      go-version: "1.26.4"
      platforms: linux/amd64
      output-dir: dist
      upload-artifacts: true
      enable-cache: true
      change-paths: '[".version",".bumpversion.toml","go.mod","go.sum","cmd/**","internal/**","pkg/**"]'
      pipelinetemplates-ref: main

  merge-version-bump:
    needs:
      - go-pr-checks
    if: >-
      needs.go-pr-checks.result == 'success' &&
      startsWith(github.event.pull_request.head.ref, 'chore/bump-version-') &&
      github.event.pull_request.base.ref == 'main'
    uses: redjax/PipelineTemplates/.forgejo/workflows/merge-version-bump.yml@main
    with:
      pr-number: ${{ github.event.pull_request.number }}
      forgejo-endpoint: ${{ github.server_url }}/api/v1
      repository: ${{ github.repository }}
    secrets:
      FJ_TOKEN: ${{ secrets.FJ_TOKEN }}
```

The branch-name condition is important:

```yaml
startsWith(github.event.pull_request.head.ref, 'chore/bump-version-')
```

It ensures that only automated version-bump pull requests are merged. Normal developer pull requests run the same CI checks but are not merged automatically.

## Expected pipeline flow

- Application changes merge into `main`
- `go-versioned-release` detects relevant Go changes
- `go-versioned-release` creates `chore/bump-version-X.Y.Z`
- Pull-request CI runs against the `version-bump` PR
- Required CI jobs succeed
- `merge-version-bump` squash-merges the `version-bump` PR
- `.version` changes on `main`
- Release workflow detects the `version-file` change
- Application artifacts are built and published as `vX.Y.Z`

The PR CI workflow should include both application paths and versioning files in its `change-paths` configuration. This ensures that ordinary Go pull requests are validated and that generated `.version` / `.bumpversion.toml` pull requests receive a successful CI result before automatic merge:

```yaml
change-paths: '[".version",".bumpversion.toml","go.mod","go.sum","cmd/**","internal/**","pkg/**"]'
```
