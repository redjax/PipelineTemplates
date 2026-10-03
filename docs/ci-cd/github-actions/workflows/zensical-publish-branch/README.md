# Zensical Publish to Branch <!-- omit in toc -->

The [`zensical-publish-branch`](../../../../../.github/workflows/zensical-publish-branch.yml) workflow publishes a built [Zensical](https://zensical.org) static-site artifact to a branch in the consuming repository, such as `gh-pages`.

It is destination-specific and contains only the artifact-download and Git push behavior needed to replace the configured branch with the generated static site. It does not run Zensical, create releases, or decide whether publishing should occur.

This target is useful for repositories or providers that publish static content by monitoring a deployment branch.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Secrets](#secrets)
- [Example use](#example-use)

## Responsibilities

- Download the Zensical build artifact from the upstream workflow run.
- Verify that the downloaded static-site artifact contains `index.html`.
- Initialize a Git repository in the downloaded artifact directory.
- Create or update the configured deployment branch.
- Force-push the generated site contents to the deployment branch.
- Avoid creating a commit when the generated site contents have not changed.

## Inputs

- `artifact-name`: Name of the generated static-site artifact to download. Default: `"zensical-site"`.
- `run-id`: Required workflow run ID containing the generated artifact.
- `branch-name`: Target branch to publish, for example `gh-pages`. Default: `"gh-pages"`.
- `commit-message`: Commit message for deployment-branch updates. Default: `"Deploy Zensical site"`.
- `runner-image`: GitHub-hosted runner image or self-hosted runner label. Default: `"ubuntu-latest"`.

## Secrets

- `push-token`: Token used to download the artifact and force-push the deployment branch.

The token needs write access to repository contents. `GITHUB_TOKEN` is sufficient for same-repository branch publishing when the caller grants `contents: write`. A PAT or GitHub App token is useful if the deployment-branch push must trigger another workflow.

## Example use

This workflow is normally called through [`zensical-publish-router`](../zensical-publish-router/) and [`zensical-publish-dispatch`](../zensical-publish-dispatch/):

```yaml
jobs:
  branch:
    if: ${{ inputs.target == 'branch' }}
    uses: ./.github/workflows/zensical-publish-branch.yml@main
    with:
      artifact-name: ${{ inputs.artifact-name }}
      run-id: ${{ inputs.run-id }}
      runner-image: ${{ inputs.runner-image }}
      branch-name: ${{ inputs.branch-name }}
      commit-message: ${{ inputs.branch-commit-message }}
    secrets:
      push-token: ${{ secrets.release-bot-pat || github.token }}
```

It can also be called independently:

```yaml
---
name: Publish Zensical Site to Deployment Branch

on:
  workflow_dispatch:

permissions:
  contents: write
  actions: read

jobs:
  publish:
    uses: redjax/pipelinetemplates/.github/workflows/zensical-publish-branch.yml@main
    with:
      artifact-name: "repository-zensical-site"
      run-id: ${{ github.run_id }}
      branch-name: "gh-pages"
      commit-message: "docs: publish static Zensical site"
      runner-image: "ubuntu-latest"
    secrets:
      push-token: ${{ github.token }}
```

For initial testing, use a disposable target branch rather than `gh-pages`:

```yaml
branch-name: "test/zensical-pages"
```
