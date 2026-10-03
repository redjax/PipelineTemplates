# Zensical Publish to Cloudflare Pages <!-- omit in toc -->

The [`zensical-publish-cloudflare-pages`](../../../../../.github/workflows/zensical-publish-cloudflare-pages.yml) workflow publishes a built [Zensical](https://zensical.org) static-site artifact to Cloudflare Pages.

It downloads the artifact produced by [`zensical-build`](../zensical-build/), validates it, ensures the configured Cloudflare Pages project exists, and performs a Wrangler direct upload. The workflow does not run Zensical itself.

This deployment model is intended for repositories that use GitHub Actions as the build/deployment control plane. Disable conflicting automatic Git-based deployments in Cloudflare Pages when this workflow is responsible for publishing.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Secrets](#secrets)
- [Example use](#example-use)

## Responsibilities

- Download the Zensical static-site artifact from the upstream workflow run.
- Verify that the artifact contains the generated `index.html`.
- Install a pinned Wrangler CLI version.
- Create the Cloudflare Pages project when it does not already exist.
- Upload the generated site artifact to the specified Cloudflare Pages project and branch.

## Inputs

- `artifact-name`: Name of the generated static-site artifact. Default: `"zensical-site"`.
- `run-id`: Required workflow run ID containing the artifact.
- `cloudflare-pages-project`: Required Cloudflare Pages project name.
- `cloudflare-pages-branch`: Cloudflare Pages production or preview branch. Default: `"main"`.
- `wrangler-version`: Version of Wrangler to install. Default: `"4.51.0"`.
- `runner-image`: GitHub-hosted runner image or self-hosted runner label. Default: `"ubuntu-latest"`.

## Secrets

- `cloudflare-api-token`: Cloudflare API token with permission to create/deploy Cloudflare Pages projects.
- `cloudflare-account-id`: Cloudflare account ID that owns the Pages project.

Create a scoped Cloudflare token with the minimum permissions required for Pages deployment. The token is passed to Wrangler as `CLOUDFLARE_API_TOKEN`.

## Example use

This workflow is normally called through [`zensical-publish-router`](../zensical-publish-router/) and [`zensical-publish-dispatch`](../zensical-publish-dispatch/):

```yaml
jobs:
  cloudflare-pages:
    if: ${{ inputs.target == 'cloudflare-pages' }}
    uses: ./.github/workflows/zensical-publish-cloudflare-pages.yml
    with:
      artifact-name: ${{ inputs.artifact-name }}
      run-id: ${{ inputs.run-id }}
      runner-image: ${{ inputs.runner-image }}
      cloudflare-pages-project: ${{ inputs.cloudflare-pages-project }}
      cloudflare-pages-branch: ${{ inputs.cloudflare-pages-branch }}
      wrangler-version: ${{ inputs.cloudflare-wrangler-version }}
    secrets:
      cloudflare-api-token: ${{ secrets.cloudflare-api-token }}
      cloudflare-account-id: ${{ secrets.cloudflare-account-id }}
```

It can also be called independently:

```yaml
---
name: Publish Zensical Site to Cloudflare Pages

on:
  workflow_dispatch:

permissions:
  contents: read
  actions: read

jobs:
  publish:
    uses: redjax/pipelinetemplates/.github/workflows/zensical-publish-cloudflare-pages.yml@main
    with:
      artifact-name: "repository-zensical-site"
      run-id: ${{ github.run_id }}
      cloudflare-pages-project: "repository-docs"
      cloudflare-pages-branch: "main"
      wrangler-version: "4.51.0"
      runner-image: "ubuntu-latest"
    secrets:
      cloudflare-api-token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
      cloudflare-account-id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
```
