# Hugo Publish Router <!-- omit in toc -->

The [`hugo-publish-router`](../../../../../.github/workflows/hugo-publish-router.yml) workflow is responsible for routing publish targets from the [`hugo-publish-dispatch`](../hugo-publish-dispatch/) workflow to publish a Hugo site's static files. It receives exactly one publish target from the dispatcher and selects the matching destination-specific reusable workflow.

This workflow keeps provider-specific inputs and secrets isolated from the dispatcher, and keeps the main orchestrator from needing to know the deployment details for each provider.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Secrets](#secrets)
- [Supported targets](#supported-targets)
- [Example Use](#example-use)

## Responsibilities

- Receive one target from `hugo-publish-dispatch`.
- Select the correct destination workflow for that target.
- Pass only the inputs and secrets that destination needs.

## Inputs

- `target`: Target name, one of:
  - `netlify`
  - `github-pages`
  - `cloudflare-pages`
  - `branch`
- `artifact-name`: Name of the build artifact.
- `run-id`: Build workflow run ID.
- `runner-image`: Runner label or image.
- `netlify-site-id`: Netlify site ID.
- `netlify-branch`: Netlify branch.
- `netlify-dir`: Netlify directory.
- `cloudflare-pages-project`: Cloudflare Pages project name.
- `cloudflare-pages-branch`: Cloudflare Pages branch.
- `branch-name`: Target branch for `branch` deploys.

## Secrets

- `netlify-auth-token`: Netlify authentication token. Required when publishing to Netlify.
- `cloudflare-api-token`: Cloudflare API token. Required when publishing to Cloudflare.
- `cloudflare-account-id`: Cloudflare account ID. Required when publishing to Cloudflare.

## Supported targets

- `netlify`: Routes to [`hugo-publish-netlify`](../hugo-publish-netlify/)
- `github-pages`: Routes to [`hugo-publish-gh-pages`](../hugo-publish-gh-pages/)
- `cloudflare-pages`: Routes to [`hugo-publish-cloudflare-pages`](../hugo-publish-cloudflare-pages/)
- `branch`: Routes to [`hugo-publish-branch`](../hugo-publish-branch/)

## Example Use

Generally called from the [dispatcher](../hugo-publish-dispatch/):

```yaml
...

jobs:
  publish:
    strategy:
      fail-fast: false
      matrix:
        target: ${{ fromJson(inputs.publish-targets) }}
    uses: ./.github/workflows/hugo-publish-router.yml
    with:
      target: ${{ matrix.target }}
      artifact-name: ${{ inputs.artifact-name }}
      run-id: ${{ inputs.run-id }}
      runner-image: ${{ inputs.runner-image }}
      netlify-site-id: ${{ inputs.netlify-site-id }}
      netlify-branch: ${{ inputs.netlify-branch }}
      netlify-dir: ${{ inputs.netlify-dir }}
      cloudflare-pages-project: ${{ inputs.cloudflare-pages-project }}
      cloudflare-pages-branch: ${{ inputs.cloudflare-pages-branch }}
      branch-name: ${{ inputs.branch-name }}
    secrets:
      netlify-auth-token: ${{ secrets.netlify-auth-token }}
      cloudflare-api-token: ${{ secrets.cloudflare-api-token }}
      cloudflare-account-id: ${{ secrets.cloudflare-account-id }}
      release-bot-pat: ${{ secrets.release-bot-pat }}

```
