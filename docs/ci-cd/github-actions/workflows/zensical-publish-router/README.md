# Zensical Publish Router <!-- omit in toc -->

The [`zensical-publish-router`](../../../../../.github/workflows/zensical-publish-router.yml) workflow routes one [Zensical](https://zensical.org) publishing target to the matching destination-specific reusable workflow.

It receives exactly one target from [`zensical-publish-dispatch`](../zensical-publish-dispatch/), then isolates provider-specific inputs and secrets from the dispatcher and from [`zensical-site-main`](../zensical-site-main/).

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Secrets](#secrets)
- [Supported targets](#supported-targets)
- [Example use](#example-use)

## Responsibilities

- Receive exactly one publishing target from `zensical-publish-dispatch`.
- Select the matching destination-specific workflow.
- Pass the generated artifact name and source workflow run ID to the destination.
- Pass only provider-specific configuration and secrets to the provider that requires them.

## Inputs

- `target`: Required publishing target name.
- `artifact-name`: Name of the generated static-site artifact. Default: `"zensical-site"`.
- `run-id`: Required workflow run ID containing the generated artifact.
- `runner-image`: GitHub-hosted runner image or self-hosted runner label.
- `cloudflare-pages-project`: Cloudflare Pages project name.
- `cloudflare-pages-branch`: Cloudflare Pages production or preview branch.
- `cloudflare-wrangler-version`: Wrangler version used for Cloudflare deployment.
- `branch-name`: Target branch for `branch` deployments.
- `branch-commit-message`: Commit message used for deployment-branch updates.

## Secrets

- `release-bot-pat`: Optional PAT or GitHub App token used by `branch` publishing.
- `cloudflare-api-token`: Required when routing to `cloudflare-pages`.
- `cloudflare-account-id`: Required when routing to `cloudflare-pages`.

## Supported targets

- `github-pages`: Routes to [`zensical-publish-gh-pages`](../zensical-publish-gh-pages/).
- `cloudflare-pages`: Routes to [`zensical-publish-cloudflare-pages`](../zensical-publish-cloudflare-pages/).
- `branch`: Routes to [`zensical-publish-branch`](../zensical-publish-branch/).

## Example use

This workflow is normally called by the dispatcher matrix:

```yaml
jobs:
  publish:
    strategy:
      fail-fast: false
      matrix:
        target: ${{ fromJson(needs.validate.outputs.publish-targets) }}
    uses: ./.github/workflows/zensical-publish-router.yml@main
    with:
      target: ${{ matrix.target }}
      artifact-name: ${{ inputs.artifact-name }}
      run-id: ${{ inputs.run-id }}
      runner-image: ${{ inputs.runner-image }}

      cloudflare-pages-project: ${{ inputs.cloudflare-pages-project }}
      cloudflare-pages-branch: ${{ inputs.cloudflare-pages-branch }}
      cloudflare-wrangler-version: ${{ inputs.cloudflare-wrangler-version }}

      branch-name: ${{ inputs.branch-name }}
      branch-commit-message: ${{ inputs.branch-commit-message }}
    secrets:
      release-bot-pat: ${{ secrets.release-bot-pat }}
      cloudflare-api-token: ${{ secrets.cloudflare-api-token }}
      cloudflare-account-id: ${{ secrets.cloudflare-account-id }}
```
