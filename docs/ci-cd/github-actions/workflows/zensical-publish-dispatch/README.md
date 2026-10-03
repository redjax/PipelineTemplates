# Zensical Publish Dispatcher <!-- omit in toc -->

The [`zensical-publish-dispatch`](../../../../../.github/workflows/zensical-publish-dispatch.yml) workflow is the fan-out layer for [Zensical](https://zensical.org) static-site publishing.

It accepts a JSON array of destination names, validates that array, expands it into a GitHub Actions matrix, and calls [`zensical-publish-router`](../zensical-publish-router/) once for each requested target.

The dispatcher does not perform provider-specific deployment work. It coordinates which targets execute after a successful static-site build and release, while passing shared artifact metadata, inputs, and secrets to the router.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Secrets](#secrets)
- [Supported targets](#supported-targets)
- [Example use](#example-use)

## Responsibilities

- Validate `publish-targets` as a JSON array of strings.
- Reject unsupported target names before a publish matrix is created.
- Require `cloudflare-pages-project` when `cloudflare-pages` is selected.
- Expand the validated target list into a matrix.
- Invoke [`zensical-publish-router`](../zensical-publish-router/) once per target.
- Pass common artifact metadata, destination configuration, and optional secrets to each routed job.

## Inputs

- `publish-targets`: Required JSON array of publishing target names.
- `artifact-name`: Name of the generated site artifact. Default: `"zensical-site"`.
- `run-id`: Required workflow run ID containing the generated artifact.
- `runner-image`: GitHub-hosted runner image or self-hosted runner label.
- `cloudflare-pages-project`: Cloudflare Pages project name. Required when `cloudflare-pages` is selected.
- `cloudflare-pages-branch`: Cloudflare Pages production or preview branch. Default: `"main"`.
- `cloudflare-wrangler-version`: Wrangler version used for Cloudflare Pages deployment. Default: `"4.51.0"`.
- `branch-name`: Target repository branch when `branch` is selected. Default: `"gh-pages"`.
- `branch-commit-message`: Commit message used for deployment-branch updates. Default: `"Deploy Zensical site"`.

## Secrets

- `release-bot-pat`: Optional PAT or GitHub App token passed to branch publishing when needed.
- `cloudflare-api-token`: Required when `cloudflare-pages` is selected.
- `cloudflare-account-id`: Required when `cloudflare-pages` is selected.

## Supported targets

- `github-pages`: Publish through the official GitHub Pages artifact/deployment actions.
- `cloudflare-pages`: Direct-upload the generated site artifact through Wrangler.
- `branch`: Force-push the generated site artifact to a repository branch.

## Example use

This workflow is normally called by [`zensical-site-main`](../zensical-site-main/):

```yaml
jobs:
  publish-standard:
    needs:
      - release-standard
    uses: ./.github/workflows/zensical-publish-dispatch.yml@main
    with:
      publish-targets: ${{ inputs.publish-targets }}
      artifact-name: ${{ inputs.artifact-name }}
      run-id: ${{ github.run_id }}
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

A consuming repository can select one or several targets:

```yaml
publish-targets: '["github-pages"]'
```

```yaml
publish-targets: '["branch"]'
branch-name: "gh-pages"
```

```yaml
publish-targets: '["github-pages","cloudflare-pages","branch"]'
cloudflare-pages-project: "repository-docs"
cloudflare-pages-branch: "main"
branch-name: "gh-pages"
```
