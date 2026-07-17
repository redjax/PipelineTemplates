# Hugo Publish to Netlify <!-- omit in toc -->

The [`hugo-publish-netlify`](../../../../../.github/workflows/hugo-publish-netlify.yml) workflow publishes a built Hugo site artifact to [Netlify](https://netlify.com). This pipeline uses the [Netlify CLI](https://docs.netlify.com/api-and-cli-guides/cli-guides/get-started-with-cli/) to upload the site and create a new deployment. You must disable automatic branch deployments in Netlify for this system to work.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Secrets](#secrets)

## Responsibilities

- Download the Hugo build artifact from the upstream build run.
- Deploy the artifact to the configured Netlify site using the Netlify CLI.

## Inputs

- `artifact-name`: Name of the build artifact to download.
- `run-id`: Build workflow run ID to download the artifact from.
- `netlify-site-id`: Netlify site ID.
- `netlify-branch`: Branch name reported to Netlify.
- `netlify-dir`: Directory to deploy to Netlify.
- `runner-image`: Runner label or image to use.

## Secrets

- `netlify-auth-token`: Netlify authentication token.
