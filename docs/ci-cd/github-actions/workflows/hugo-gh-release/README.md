# Hugo GitHub Release <!-- omit in toc -->

The `hugo-gh-release` workflow creates a Git tag and GitHub Release for a built Hugo site.

The workflow does not build the site itself. It expects the build output to already exist as a workflow artifact created by [`hugo-build`](../hugo-build/). It can be used as part of [`hugo-site-main`](../hugo-site-main/), or called independently from another repository.

> [!NOTE]
> For versioned sites, this workflow uses the version file as the source of truth for the release version. For unversioned or manual runs, it can fall back to a short commit hash-based release name and tag.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Secrets](#secrets)
- [Example use](#example-use)

## Responsibilities

- Download the built site artifact.
- Determine release metadata.
- Create a Git tag if needed.
- Create a GitHub Release.
- Attach the built site archive or artifact to the release.

## Inputs

- `site-root`: Path to the Hugo site in the consuming repository.
- `versioned`: Whether the site uses versioned releases.
- `version-file`: Path to the version file.
- `artifact-name`: Name of the build artifact to download.
- `release-prefix`: Prefix used for generated release tags.
- `build-run-id`: Workflow run ID that produced the build artifact.
- `release-tag`: Optional explicit Git tag to use.
- `runner-image`: Runner label or image to use.

## Secrets

`release-bot-pat`: PAT used for GitHub Release creation and tag-related operations (`RELEASE_BOT_PAT`).

## Example use

This workflow is usually called by [`hugo-site-main`](../hugo-site-main/):

```yaml
---
name: Hugo Site Main Pipeline

on:
  workflow_call:
    inputs:
      site-root:
        type: string
        required: false
        default: "."
      versioned:
        type: boolean
        required: false
        default: true
      version-file:
        type: string
        required: false
        default: ".version"
      artifact-name:
        type: string
        required: false
        default: "hugo-site"
      release-prefix:
        type: string
        required: false
        default: "site"
      runner-image:
        type: string
        required: false
        default: ubuntu-latest

     ...

jobs:
  ...

  release:
    needs: [build, prep]
    uses: ./.github/workflows/hugo-gh-release.yml
    with:
      site-root: ${{ inputs.site-root }}
      versioned: ${{ inputs.versioned }}
      version-file: ${{ inputs.version-file }}
      artifact-name: ${{ inputs.artifact-name }}
      release-prefix: ${{ inputs.release-prefix }}
      build-run-id: ${{ github.run_id }}
      release-tag: ${{ github.event_name == 'workflow_dispatch' && format('site-{0}', needs.prep.outputs.short-sha) || '' }}
      runner-image: ${{ inputs.runner-image }}
    secrets:
      release-bot-pat: ${{ secrets.release-bot-pat }}

```

But it can also be called independently from another repository:

```yaml
---
name: Release Hugo site

on:
  workflow_dispatch:
    inputs:
      release-tag:
        description: "Optional explicit tag"
        required: false
        type: string
      runner-img-or-label:
        description: "Runner image or self-hosted runner label"
        required: true
        type: string
        default: ubuntu-latest

permissions:
  contents: write

jobs:
  release:
    uses: redjax/pipelinetemplates/.github/workflows/hugo-gh-release.yml@main
    with:
      site-root: "."
      versioned: true
      version-file: ".version"
      artifact-name: "hugo-site"
      release-prefix: "site"
      build-run-id: ${{ github.run_id }}
      release-tag: ${{ inputs.release-tag || '' }}
      runner-image: ${{ inputs.runner-img-or-label || 'ubuntu-latest' }}
    secrets:
      release-bot-pat: ${{ secrets.RELEASE_BOT_PAT }}

```
