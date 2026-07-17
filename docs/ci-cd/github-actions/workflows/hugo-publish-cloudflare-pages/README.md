# Hugo Publish to Cloudflare Pages <!-- omit in toc -->

The [`hugo-publish-cloudflare-pages`](../../../../../.github/workflows/hugo-publish-cloudflare-pages.yml) workflow publishes a built Hugo site artifact to Cloudflare Pages. It is destination-specific and contains only the inputs, secrets, and Wrangler-based deploy logic needed for Cloudflare Pages.

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
