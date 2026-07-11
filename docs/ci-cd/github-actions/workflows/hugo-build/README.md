# Hugo Build <!-- omit in toc -->

The `hugo-build` workflow builds the Hugo site and uploads the generated output as a workflow artifact.

The workflow can be triggered manually, or automatically i.e. a PR merge to `main`. It does not decide release or publish behavior, it only builds and packages the site.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Example use](#example-use)

## Responsibilities

- Check-out the consuming repository repository.
- Build the Hugo site.
- Produce the site `output/` directory.
- Upload the build result as a pipeline artifact artifact.

## Inputs

- `site-root`: Path to the Hugo site in the caller repository.
- `public-dir`: Output directory for the built site.
- `artifact-name`: Name of the uploaded artifact.
- `build-flags`: Extra flags passed to the Hugo build command.
- `runner-image`: Runner label or image to use.

## Example use

This workflow is usually called by [`hugo-site-main`](../hugo-site-main/):

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

      hugo-build-flags:
        description: "Optional Hugo build command flags, i.e. --gc and --minify"
        type: string
        required: false
        default: "--gc --minify --enableGitInfo"

      ...

jobs:
  ## Steps that apply to logical branches in the script, i.e.
  #  every step needs to checkout the code, so do it once here.
  prep:
    needs: [bump]
    runs-on: ${{ inputs.runner-image }}
    outputs:
      short-sha: ${{ steps.vars.outputs.short-sha }}
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0
      - name: Compute short sha
        id: vars
        shell: bash
        run: echo "short-sha=$(git rev-parse --short=7 ${{ github.sha }})" >> "$GITHUB_OUTPUT"

  build:
    needs: [prep]
    uses: ./.github/workflows/hugo-build.yml
    with:
      site-root: ${{ inputs.site-root }}
      artifact-name: ${{ inputs.artifact-name }}
      public-dir: ${{ inputs.site-root }}/public
      build-flags: ${{ inputs.hugo-build-flags }}
      runner-image: ${{ inputs.runner-image }}
    secrets: inherit

```

But can be called independently from another repository:

```yaml
---
name: Test Hugo site build

on:
  pull_request:
    branches:
      - main
    types:
      - opened
      - synchronize
      - reopened
    paths:
      - "apps/hugo-site/archetypes/**"
      - "apps/hugo-site/content/**"
      - "apps/hugo-site/data/**"
      - "apps/hugo-site/i18n/**"
      - "apps/hugo-site/static/**"
      - "apps/hugo-site/hugo.yml"
      - "apps/hugo-site/go.mod"
      - "apps/hugo-site/go.sum"

  workflow_dispatch:
    inputs:
      runner-img-or-label:
        description: "A runner image (i.e. ubuntu-latest) or self-hosted runner label (i.e. pipelinetemplates-test)"
        required: true
        type: string
        default: ubuntu-latest

permissions:
  actions: write
  contents: write

jobs:
  build:
    uses: redjax/pipelinetemplates/.github/workflows/hugo-build.yml@main
    with:
      ## Path where Hugo was initialized. Use "." for repository root.
      site-root: "apps/hugo-site"
      artifact-name: "hugo-site"
      public-dir: "apps/hugo-site/public"
      build-flags: "--gc --minify --enableGitInfo"
      # runner-image: ${{ inputs.use-selfhosted-runner && 'pipelinetemplates-test' || 'ubuntu-latest' }}
      runner-image: ${{ inputs.runner-img-or-label || 'ubuntu-latest' }}
    secrets: inherit

```
