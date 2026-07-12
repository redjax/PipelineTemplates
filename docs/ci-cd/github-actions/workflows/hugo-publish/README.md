# Hugo Publish <!-- omit in toc -->

The `hugo-publish` workflow publishes a built Hugo site to one of several supported destinations. The workflow does not build the site; it expects the site output to already be available as a workflow artifact from the [`hugo-build` workflow](../hugo-build/).

Currently supported publish targets:

- A branch in the consuming repository
- Github Pages
- Cloudflare Pages

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Secrets](#secrets)
- [Example use](#example-use)

## Responsibilities

- Download the Hugo artifact built in [`hugo-build`](../hugo-build/).
- Publish the artifact to the selected target (`branch`, `gh-pages`, etc).
- Support branch deployment (i.e. `gh-pages`).
- Support GitHub Pages deployment using release asset.
- Support Cloudflare Pages deployment using release asset.

## Inputs

- `target`: Publish target, such as `branch`, `github-pages`, `cloudflare-pages`, or `github-release`.
- `run-id`: Build workflow run ID to download the artifact from.
- `artifact-name`: Name of the build artifact to download.
- `branch-name`: Target branch for `branch` deploys.
- `commit-message`: Commit message for `branch` deploys.
- `cloudflare-pages-project`: Cloudflare Pages project name.
- `cloudflare-pages-branch`: Branch name reported to Cloudflare Pages.
- `cloudflare-pages-directory`: Directory to deploy to Cloudflare Pages.
- `release-name`: GitHub release name.
- `release-version`: (Optional) Version string used to build a tag and archive names.
- `release-tag`: (Optional) Explicit Git tag to use for the GitHub release.
- `dry-run`: If `true`, do not push or deploy.
- `runner-image`: Runner label or image to use.

## Secrets

- `cloudflare-api-token`: Cloudflare API token with permission to write to Pages (`CLOUDFLARE_API_TOKEN`).
- `cloudflare-account-id`: Account ID of owning Cloudflare account where Pages are deployed (`CLOUDFLARE_ACCOUNT_ID`).

## Example use

This workflow is usually called by hugo-site-main:

```yaml
---
name: Hugo Site Main Pipeline

on:
  workflow_call:
    inputs:
      ...

      artifact-name:
        type: string
        required: false
        default: "hugo-site"
      runner-image:
        type: string
        required: false
        default: ubuntu-latest
      publish-gh-pages:
        type: boolean
        required: false
        default: false
      publish-target:
        type: string
        required: false
        default: ""

      ...

...

jobs:
  publish:
    if: ${{ inputs.publish-gh-pages || inputs.publish-target != '' }}
    needs: [release]
    uses: redjax/pipelinetemplates/.github/workflows/hugo-publish.yml@main
    with:
      target: ${{ inputs.publish-target != '' && inputs.publish-target || 'github-pages' }}
      artifact-name: ${{ inputs.artifact-name }}
      run-id: ${{ github.run_id }}
      runner-image: ${{ inputs.runner-image }}
    secrets:
      cloudflare-api-token: ${{ secrets.cloudflare-api-token }}
      cloudflare-account-id: ${{ secrets.cloudflare-account-id }}

```

But it can also be called independently from another repository:

```yaml
---
name: Publish Hugo site

on:
  workflow_dispatch:
    inputs:
      target:
        description: "Publish target"
        required: true
        type: choice
        options:
          - branch
          - github-pages
          - cloudflare-pages
          - github-release
      runner-img-or-label:
        description: "Runner image or self-hosted runner label"
        required: true
        type: string
        default: ubuntu-latest

permissions:
  contents: write
  pages: write
  id-token: write

jobs:
  publish:
    uses: redjax/pipelinetemplates/.github/workflows/hugo-publish.yml@main
    with:
      target: ${{ inputs.target }}
      artifact-name: "hugo-site"
      run-id: ${{ github.run_id }}
      runner-image: ${{ inputs.runner-img-or-label || 'ubuntu-latest' }}
    secrets:
      cloudflare-api-token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
      cloudflare-account-id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}

```
