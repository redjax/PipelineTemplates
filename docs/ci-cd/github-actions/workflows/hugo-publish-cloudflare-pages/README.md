# Hugo Publish to Cloudflare Pages <!-- omit in toc -->

The [`hugo-publish-cloudflare-pages`](../../../../../.github/workflows/hugo-publish-cloudflare-pages.yml) workflow publishes a built Hugo site artifact to Cloudflare Pages.

This pipeline assumes you have disabled automatic deployments from a changed branch in Github. It uses the [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/) and a [Cloudflare API token](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/) to upload the site. The Cloudflare token must have `Pages: write` access.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Secrets](#secrets)

## Responsibilities

- Download the Hugo build artifact from the upstream build run.
- Ensure the Cloudflare Pages project exists.
- Deploy the artifact to the specified Cloudflare Pages project and branch.

## Inputs

- `artifact-name`: Name of the build artifact to download.
- `run-id`: Build workflow run ID to download the artifact from.
- `cloudflare-pages-project`: Cloudflare Pages project name.
- `cloudflare-pages-branch`: Branch name reported to Cloudflare Pages.
- `runner-image`: Runner label or image to use.

## Secrets

- `cloudflare-api-token`: Cloudflare API token with Pages write permission.
- `cloudflare-account-id`: Cloudflare account ID.
