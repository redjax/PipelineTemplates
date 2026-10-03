# Zensical Version Bump <!-- omit in toc -->

The `zensical-version-bump` workflow calculates and applies a semantic version bump for a versioned [Zensical](https://zensical.org) site.

It checks out the consuming repository, checks out PipelineTemplates to obtain the shared Zensical bump script, runs a pinned `bump-my-version` tool through UV, updates the configured versioned files, then creates or updates an automated pull request.

The workflow does not build, tag, release, or publish the static site. Those actions occur later, after the automated bump pull request merges and its merge commit triggers [`zensical-site-main`](../zensical-site-main/).

> [!NOTE]
> Versioning uses [`bump-my-version`](https://github.com/callowayproject/bump-my-version). The consuming repository must contain a version file, normally `.version`, and a compatible `.bumpversion.toml` configuration.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Bump behavior](#bump-behavior)
- [Inputs](#inputs)
  - [Version files and source paths](#version-files-and-source-paths)
  - [Pull request behavior](#pull-request-behavior)
  - [Runtime behavior](#runtime-behavior)
- [Secrets](#secrets)
- [Required repository settings](#required-repository-settings)
- [Example use](#example-use)

## Responsibilities

- Check out the consuming repository.
- Check out PipelineTemplates at `templates-ref` to access the shared Zensical bump script.
- Set up a pinned Python and `bump-my-version` environment through UV.
- Determine whether the triggering commit or merged changes modified configured Zensical-relevant paths.
- Determine major, minor, or patch behavior from Conventional Commit messages.
- Update the versioned files configured in `.bumpversion.toml`.
- Create or update an automated version-bump pull request.
- Enable pull-request auto-merge when the repository allows it.

## Bump behavior

The shared script examines only commits that modify configured relevant paths.

Paths can be provided in either form:

- `changed-paths-file`: A repository-relative file containing newline-delimited Git pathspecs.
- `changed-paths`: Newline-delimited Git pathspecs passed directly as workflow input.

When neither is supplied, the script uses these defaults:

```text
docs/
zensical.toml
mkdocs.yml
mkdocs.yaml
mkdocs.toml
```

The bump type is determined from the matching commit messages:

| Commit message pattern                                                 | Result     |
| ---------------------------------------------------------------------- | ---------- |
| `feat!:` or a body containing `BREAKING CHANGE:` / `BREAKING CHANGES:` | Major bump |
| `feat:` or `feat(scope):`                                              | Minor bump |
| `fix:` or `fix(scope):`                                                | Patch bump |
| Any other matching commit                                              | Patch bump |

For example:

```text
feat(docs): add Zensical deployment documentation
```

causes a minor version bump.

```text
fix(docs): repair GitHub Pages deployment guide
```

causes a patch version bump.

## Inputs

### Version files and source paths

- `version-file`: Repository-relative version file. Default: `".version"`.
- `bump-config`: Repository-relative `bump-my-version` configuration file. Default: `".bumpversion.toml"`.
- `bump-script`: PipelineTemplates-relative shared script path. Default: `"shared/scripts/ci-cd/zensical/bump-site-version.sh"`.
- `changed-paths-file`: Optional repository-relative file containing newline-delimited Git pathspecs.
- `changed-paths`: Optional inline newline-delimited Git pathspecs.

### Pull request behavior

- `pr-branch`: Branch used for the automated bump PR. Default: `"bump/zensical-site-version"`.
- `base-branch`: Target branch for the bump PR. Default: `"main"`.
- `pr-title`: Pull request title and bump commit message.
- `pr-body`: Pull request body.
- `pr-labels`: Comma-separated labels applied to the PR.
- `dry-run`: Calculate the bump but do not modify files or create/merge a PR. Default: `false`.

### Runtime behavior

- `python-version`: Python version used by the pinned bump tool. Default: `"3.13"`.
- `bump-my-version-version`: Pinned `bump-my-version` version. Default: `"1.5.1"`.
- `runner-image`: GitHub-hosted runner image or self-hosted runner label.
- `templates-ref`: PipelineTemplates branch, tag, or commit containing `bump-script`. Default: `"main"`.

## Secrets

- `release-bot-pat`: Optional PAT or GitHub App token used to create/update and auto-merge the bump pull request.

`GITHUB_TOKEN` can create the bump PR when the caller grants `contents: write` and `pull-requests: write`. Use a PAT or GitHub App token when downstream workflow runs must be triggered by pull-request creation, branch updates, or the eventual merge.

## Required repository settings

For automated PR creation with `GITHUB_TOKEN`, enable the repository setting:

```text
Settings
  → Actions
    → General
      → Workflow permissions
        → Allow GitHub Actions to create and approve pull requests
```

Enable auto-merge in repository settings if `gh pr merge --auto` should merge the automated PR after required checks pass.

The consuming repository needs a version file and a `bump-my-version` configuration. Minimal examples:

`.version`:

```text
0.1.0
```

`.bumpversion.toml`:

```toml
[tool.bumpversion]
current_version = "0.1.0"
commit = false
tag = false

[[tool.bumpversion.files]]
filename = ".version"
```

## Example use

This workflow is normally called by [`zensical-site-main`](../zensical-site-main/):

```yaml
jobs:
  bump:
    if: ${{ needs.decide.outputs.should-bump == 'true' }}
    needs: decide
    uses: ./.github/workflows/zensical-version-bump.yml
    with:
      version-file: ${{ inputs.version-file }}
      bump-config: ${{ inputs.bump-config }}
      bump-script: ${{ inputs.bump-script }}

      changed-paths-file: ${{ inputs.bump-changed-paths-file }}
      changed-paths: ${{ inputs.bump-changed-paths }}

      pr-branch: ${{ inputs.bump-pr-branch }}
      base-branch: ${{ inputs.bump-base-branch }}
      pr-title: "chore(release): bump Zensical site version [zensical-version-bump]"
      pr-body: "Automated version bump for Zensical site changes."

      python-version: "3.13"
      bump-my-version-version: "1.5.1"

      runner-image: ${{ inputs.runner-image }}
      templates-ref: ${{ inputs.templates-ref }}
    secrets:
      release-bot-pat: ${{ secrets.release-bot-pat }}
```

It can also be called independently:

```yaml
---
name: Bump Zensical Site Version

on:
  push:
    branches:
      - main
    paths:
      - "docs/**"
      - "docs-site/**"
      - "zensical.toml"
      - ".version"
      - ".bumpversion.toml"

permissions:
  contents: write
  pull-requests: write

jobs:
  bump:
    uses: redjax/pipelinetemplates/.github/workflows/zensical-version-bump.yml@main
    with:
      version-file: ".version"
      bump-config: ".bumpversion.toml"

      changed-paths: |
        docs/
        docs-site/pyproject.toml
        docs-site/uv.lock
        zensical.toml

      pr-branch: "bump/zensical-site-version"
      base-branch: "main"
      templates-ref: "main"
    secrets:
      release-bot-pat: ${{ secrets.RELEASE_BOT_PAT }}
```
