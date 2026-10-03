# Zensical GitHub Release <!-- omit in toc -->

The `zensical-gh-release` workflow creates a Git tag and GitHub Release for a built [Zensical](https://zensical.org) static site.

The workflow does not build the site itself. It expects the build output to already exist as a workflow artifact created by [`zensical-build`](../zensical-build/). It downloads that artifact, resolves release metadata, creates a tag when necessary, packages the static site as `.tar.gz` and `.zip` archives, and attaches those archives to a GitHub Release.

For versioned sites, the configured version file is the source of truth. For standard, non-versioned, or manual runs, the workflow can use an explicit release tag or fall back to a short Git SHA-based tag.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Secrets](#secrets)
- [Release naming](#release-naming)
- [Example use](#example-use)

## Responsibilities

- Download a generated static-site artifact from the specified workflow run.
- Validate that the downloaded artifact exists and is non-empty.
- Resolve release version, tag, and GitHub Release name.
- Create an annotated Git tag if the tag does not already exist.
- Package the static-site artifact as `.tar.gz` and `.zip` archives.
- Create a GitHub Release and upload both archive files.

## Inputs

- `versioned`: Whether the version is read from `version-file`. Default: `true`.
- `version-file`: Repository-relative file containing the site version. Default: `".version"`.
- `artifact-name`: Name of the generated static-site artifact to download. Default: `"zensical-site"`.
- `release-prefix`: Prefix used for generated release tags. Default: `"site"`.
- `release-version`: Optional explicit release version.
- `release-name`: Optional explicit GitHub Release name.
- `release-tag`: Optional explicit Git tag.
- `build-run-id`: Required workflow run ID containing `artifact-name`.
- `checkout-ref`: Optional repository ref to tag. An empty value uses the triggering ref.
- `create-github-release`: Whether to create the GitHub Release and upload archives. Default: `true`.
- `runner-image`: GitHub-hosted runner image or self-hosted runner label. Default: `"ubuntu-latest"`.

## Secrets

- `release-bot-pat`: Optional PAT or GitHub App token used instead of `GITHUB_TOKEN`.

The workflow defaults to `GITHUB_TOKEN` for same-repository checkout, artifact download, tag push, and release creation. The calling workflow must grant `contents: write` and `actions: read` or equivalent permissions.

Use `release-bot-pat` when a tag or release must trigger separate downstream GitHub Actions workflows, when repository policy prevents `GITHUB_TOKEN` writes, or when a distinct bot/service identity is required.

## Release naming

| Mode                   | Version source                           | Default tag and GitHub Release name |
| ---------------------- | ---------------------------------------- | ----------------------------------- |
| Versioned              | Contents of `version-file`               | `<release-prefix>-v<version>`       |
| Standard/non-versioned | Triggering commit short SHA              | `<release-prefix>-<short-sha>`      |
| Explicit               | `release-tag`, optionally `release-name` | Caller-provided values              |

For example, with:

```yaml
versioned: true
version-file: ".version"
release-prefix: "site"
```

and a version file containing:

```text
1.2.3
```

the resolved tag and release name are:

```text
site-v1.2.3
```

## Example use

This workflow is normally called by [`zensical-site-main`](../zensical-site-main/):

```yaml
jobs:
  release-versioned:
    needs:
      - build-versioned
    uses: ./.github/workflows/zensical-gh-release.yml@main
    with:
      versioned: true
      version-file: ${{ inputs.version-file }}
      artifact-name: ${{ inputs.artifact-name }}
      build-run-id: ${{ github.run_id }}
      release-prefix: ${{ inputs.release-prefix }}
      create-github-release: true
      runner-image: ${{ inputs.runner-image }}
```

It can also be called independently from another repository after a build job uploads an artifact:

```yaml
---
name: Release Zensical Site

on:
  workflow_dispatch:
    inputs:
      release-tag:
        description: "Optional explicit release tag."
        required: false
        type: string
        default: ""

permissions:
  contents: write
  actions: read

jobs:
  release:
    uses: redjax/pipelinetemplates/.github/workflows/zensical-gh-release.yml@main
    with:
      versioned: false
      artifact-name: "repository-zensical-site"
      build-run-id: ${{ github.run_id }}

      release-prefix: "site"
      release-tag: ${{ inputs.release-tag }}
      release-name: ${{ inputs.release-tag }}

      checkout-ref: ${{ github.sha }}
      create-github-release: true
      runner-image: "ubuntu-latest"
```

The release workflow must run in the same workflow run that produced the artifact, or the supplied `build-run-id` must identify a run whose artifact is accessible to the job token.
