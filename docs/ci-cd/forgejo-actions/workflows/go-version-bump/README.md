# Go Version Bump <!-- omit in toc -->

The [`go-version-bump` workflow](../../../../../.forgejo/workflows/go-version-bump.yml) updates a repository version using [`bump-my-version`](https://github.com/callowayproject/bump-my-version), creates a dedicated version-bump branch, and opens a pull request against the configured base branch.

The workflow is intended for versioned Go repositories. It does not build binaries, create Git tags, create Forgejo releases, or upload release assets.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Example use](#example-use)

## Responsibilities

- Check-out the consuming repository at the configured base branch.
- Check-out PipelineTemplates at the requested revision.
- Install bump-my-version.
- Determine the selected version bump type.
- Update the configured version file.
- Create a version-bump branch.
- Commit version-related file changes.
- Push the version-bump branch.
- Create or reuse an open Forgejo pull request.
- Return the version-bump branch and pull request number as outputs.

## Inputs

- `bump-type`: Version bump type: `auto`, `major`, `minor`, or `patch`.
- `version-file`: Version file path relative to the repository root.
- `bumpversion-config`: Path to the bump-my-version configuration file.
- `base-branch`: Branch that receives the version-bump pull request.
- `pipelinetemplates-ref`: PipelineTemplates revision to check out.
- `forgejo-endpoint`: Forgejo API endpoint.
- `repository`: Repository in `owner/name` form.
- `FJ_TOKEN`: Forgejo token used to create the pull request.

## Example use

This workflow can be called directly from a trusted release pipeline after application changes have been merged:

```yaml
---
name: Version Bump

on:
  push:
    branches:
      - main

jobs:
  bump-version:
    uses: redjax/PipelineTemplates/.forgejo/workflows/go-version-bump.yml@main
    with:
      bump-type: auto
      version-file: ".version"
      bumpversion-config: ".bumpversion.toml"
      base-branch: main
      pipelinetemplates-ref: main
      forgejo-endpoint: ${{ github.server_url }}/api/v1
      repository: ${{ github.repository }}
    secrets:
      FJ_TOKEN: ${{ secrets.FJ_TOKEN }}
```

The consuming repository should also provide a `.bumpversion.toml` for `bump-my-version`. For example, a repository using a file named `.version` to track the version could provide this `.bumpversion.toml`:

```toml
[tool.bumpversion]
current_version = "0.0.1"
parse = "(?P<major>\\d+)\\.(?P<minor>\\d+)\\.(?P<patch>\\d+)"
serialize = ["{major}.{minor}.{patch}"]

[[tool.bumpversion.files]]
filename = ".version"

```
