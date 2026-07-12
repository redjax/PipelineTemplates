# Hugo Version Bump <!-- omit in toc -->

The `hugo-version-bump` workflow bumps the Hugo site version for versioned sites. It uses the caller repository's working tree for the site files, and it checks out the templates repository to run the shared bump script.

>[!NOTE]
> The version bumping process is built around using [`bump-my-version`](https://github.com/callowayproject/bump-my-version). It expects the consuming repository to have a version file (default: `.version`), and a `.bumpversion.toml` configuration.

The consuming repo must provide a release bot secret, which is a Github PAT named `RELEASE_BOT_PAT` with permissions to write contents and merge PRs. Pipelines that use this step must also have a step to checkout the `PipelineTemplates` repository, so the pipeline can find the `bump-site-version.sh` script.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Secrets](#secrets)
- [Example use](#example-use)

## Responsibilities

- Install `bump-my-version`.
- Run the [shared Hugo bump script](../../../../../shared/scripts/ci-cd/hugo/bump-site-version.sh).
- Update the version file and bump config.
- Create or update a bump PR.
- Auto-merge the PR when CI checks complete.

## Inputs

- `site-root`: Path to the Hugo site in the consuming repository.
- `bump-script`: Path to the bump script in the templates repository.
- `bump-config`: Path to the bump configuration file.
- `version-file`: Path to the version file.
- `pr-branch`: Branch name used for the bump PR.
- `pr-title`: PR title.
- `pr-body`: PR body text.
- `pr-labels`: Labels to apply to the PR.
- `dry-run`: If true, skip file mutation and PR creation.
- `runner-image`: Runner label or image to use.
- `templates-ref`: Ref used to checkout the templates repository.

## Secrets

- `release-bot-pat`: PAT used to create and merge the bump PR.

## Example use

This workflow is usually called by [`hugo-site-main`](../hugo-site-main/):

```yaml
---
name: Hugo Site Main Pipeline

on:
  workflow_call:
    inputs:
      site-root:
        type: string
        required: false
        default: "."
      versioned:
        type: boolean
        required: false
        default: true
      version-file:
        type: string
        required: false
        default: ".version"

      ...

permissions:
  contents: write
  actions: write
  pull-requests: write
  pages: write
  id-token: write

jobs:
  ## Trigger a bump if calling pipeline requests it and calling site is versioned.
  bump:
    if: ${{ github.event_name == 'push' && inputs.versioned }}
    uses: ./.github/workflows/hugo-version-bump.yml
    with:
      site-root: ${{ inputs.site-root }}
      bump-script: ${{ inputs.bump-script }}
      bump-config: ${{ inputs.bump-config }}
      version-file: ${{ inputs.version-file }}
      runner-image: ${{ inputs.runner-image }}
      templates-ref: ${{ inputs.templates-ref }}
    secrets:
      release-bot-pat: ${{ secrets.release-bot-pat }}

```

But can be called independently from another repository:

```yaml
---
name: Bump Hugo site version

on:
  ## Automated bump on merge to main when Hugo files have changed
  push:
    branches:
      - main
    paths:
      - "apps/hugo-site/archetypes/**"
      - "apps/hugo-site/content/**"
      - "apps/hugo-site/data/**"
      - "apps/hugo-site/i18n/**"
      - "apps/hugo-site/static/**"
      - "apps/hugo-site/hugo.yml"
      - "apps/hugo-site/go.mod"
      - "apps/hugo-site/go.sum"

permissions:
  contents: write
  pull-requests: write

jobs:
  ## Trigger a bump if calling pipeline requests it and calling site is versioned.
  bump:
    if: ${{ github.event_name == 'push' && inputs.versioned }}
    uses: redjax/pipelinetemplates/.github/workflows/hugo-version-bump.yml@main
    with:
      site-root: ${{ inputs.site-root }}
      bump-script: ${{ inputs.bump-script }}
      bump-config: ${{ inputs.bump-config }}
      version-file: ${{ inputs.version-file }}
      runner-image: ${{ inputs.runner-image }}
      templates-ref: ${{ inputs.templates-ref }}
    secrets:
      release-bot-pat: ${{ secrets.release-bot-pat }}
```
