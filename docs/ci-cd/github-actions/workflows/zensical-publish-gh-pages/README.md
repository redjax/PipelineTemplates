# Zensical Publish to GitHub Pages <!-- omit in toc -->

The [`zensical-publish-gh-pages`](../../../../../.github/workflows/zensical-publish-gh-pages.yml) workflow publishes a built [Zensical](https://zensical.org) static-site artifact to GitHub Pages.

It is destination-specific and contains only the artifact-download, GitHub Pages configuration, Pages artifact upload, and deployment steps. It does not run Zensical, create a Git tag, or create a GitHub Release.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Required permissions](#required-permissions)
- [Example use](#example-use)

## Responsibilities

- Download the Zensical static-site artifact from the upstream workflow run.
- Validate that the downloaded artifact contains `index.html`.
- Configure GitHub Pages.
- Upload the static site as a GitHub Pages artifact.
- Deploy the Pages artifact with the official GitHub Pages deployment action.
- Set the deployed Pages URL as the job environment URL.

## Inputs

- `artifact-name`: Name of the generated static-site artifact to deploy. Default: `"zensical-site"`.
- `run-id`: Required workflow run ID containing the generated artifact.
- `runner-image`: GitHub-hosted runner image or self-hosted runner label. Default: `"ubuntu-latest"`.

## Required permissions

The caller must grant:

```yaml
permissions:
  contents: read
  actions: read
  pages: write
  id-token: write
```

The repository must also be configured to use **GitHub Actions** as its GitHub Pages build/deployment source.

## Example use

This workflow is normally called through [`zensical-publish-router`](../zensical-publish-router/) and [`zensical-publish-dispatch`](../zensical-publish-dispatch/):

```yaml
jobs:
  github-pages:
    if: ${{ inputs.target == 'github-pages' }}
    uses: ./.github/workflows/zensical-publish-gh-pages.yml
    with:
      artifact-name: ${{ inputs.artifact-name }}
      run-id: ${{ inputs.run-id }}
      runner-image: ${{ inputs.runner-image }}
```

It can also be called independently:

```yaml
---
name: Publish Zensical Site to GitHub Pages

on:
  workflow_dispatch:

permissions:
  contents: read
  actions: read
  pages: write
  id-token: write

jobs:
  publish:
    uses: redjax/pipelinetemplates/.github/workflows/zensical-publish-gh-pages.yml@main
    with:
      artifact-name: "repository-zensical-site"
      run-id: ${{ github.run_id }}
      runner-image: "ubuntu-latest"
```
