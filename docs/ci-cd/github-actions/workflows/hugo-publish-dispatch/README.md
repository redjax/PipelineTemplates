# Hugo Publish Dispatcher <!-- omit in toc -->

The [`hugo-publish-dispatch](../../../../../.github/workflows/hugo-publish-dispatch.yml) workflow is the "fan-out" layer for publishing a Hugo site. It accepts a JSON array of publish targets, expands them into a matrix, and invokes the [publish router](../hugo-publish-router) once per target.

This workflow only coordinates which targets should run for the current pipeline lane (versioned or standard/manual), and passes shared publish inputs downstream.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Secrets](#secrets)
- [Example use](#example-use)

## Responsibilities

- Accept a JSON array of publish targets from `hugo-site-main`.
- Expand the target list into a matrix of jobs.
- Call [`hugo-publish-router`](../hugo-publish-router) once per target.
- Pass shared inputs and secrets to the router.

## Inputs

- `publish-targets`: JSON array of target names, e.g. `["github-pages","branch"]`.
- `artifact-name`: Name of the build artifact to download.
- `run-id`: Build workflow run ID to download the artifact from.
- `runner-image`: Runner label or image to use.
- `netlify-site-id`: Netlify site ID (used when `netlify` is a target).
- `netlify-branch`: Branch name reported to Netlify.
- `netlify-dir`: Directory to deploy to Netlify.
- `cloudflare-pages-project`: Cloudflare Pages project name.
- `cloudflare-pages-branch`: Branch name reported to Cloudflare Pages.
- `branch-name`: Target branch for `branch` deploys.

## Secrets

- `netlify-auth-token`: Netlify authentication token.
- `cloudflare-api-token`: Cloudflare API token with Pages write permission.
- `cloudflare-account-id`: Cloudflare account ID.

## Example use

This workflow is usually called by [`hugo-site-main`](../hugo-site-main/):

```yaml
name: Hugo Site Main Pipeline

on:
  workflow_call:
    inputs:
      ...

...

jobs:
  ...

  publish-dispatch-versioned:
    if: ${{ github.event_name == 'push' && inputs.versioned && inputs.publish-targets != '[]' }}
    needs: [release-versioned]
    uses: ./.github/workflows/hugo-publish-dispatch.yml
    with:
      publish-targets: ${{ inputs.publish-targets }}
      artifact-name: ${{ inputs.artifact-name }}
      run-id: ${{ github.run_id }}
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

  publish-dispatch-standard:
    if: ${{ !(github.event_name == 'push' && inputs.versioned) && inputs.publish-targets != '[]' }}
    needs: [release-standard]
    uses: ./.github/workflows/hugo-publish-dispatch.yml
    with:
      publish-targets: ${{ inputs.publish-targets }}
      artifact-name: ${{ inputs.artifact-name }}
      run-id: ${{ github.run_id }}
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

```
