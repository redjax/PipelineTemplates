# Zensical Build <!-- omit in toc -->

The `zensical-build` workflow builds a [Zensical](https://zensical.org) static documentation site and uploads the generated output as a GitHub Actions workflow artifact.

The workflow is responsible only for checking out the consuming repository, preparing Python and UV, running the shared `zensical-build` composite action, validating the generated site, and uploading the build artifact. It does not create tags, GitHub Releases, or deployments.

Zensical is executed through the consuming repository's UV project:

```bash
uv run --project <python-project-dir> zensical build
```

This workflow supports layouts where the Zensical configuration file, documentation source, UV project, and generated site directory are in different repository-relative paths.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
  - [Zensical project paths](#zensical-project-paths)
  - [Build behavior](#build-behavior)
  - [Artifact handling](#artifact-handling)
- [Outputs](#outputs)
- [Example use](#example-use)

## Responsibilities

- Check out the consuming repository at the triggering ref or an explicit `checkout-ref`.
- Run the shared [`zensical-build` composite action](../../../../../.github/actions/zensical-build/).
- Set up the requested Python version and UV environment.
- Synchronize the UV project dependencies.
- Build the Zensical static site.
- Validate that the configured output directory exists and is non-empty.
- Upload the generated site as a workflow artifact.

## Inputs

### Zensical project paths

- `working-directory`: Repository-relative directory from which Zensical runs. Default: `"."`.
- `python-project-dir`: Repository-relative UV project directory containing `pyproject.toml`. Default: `"."`.
- `zensical-config`: Optional repository-relative path to `zensical.toml` or compatible MkDocs configuration. Leave empty to use Zensical configuration discovery.
- `docs-dir`: Optional repository-relative documentation source directory. It is used for validation and changed-path detection and must agree with the Zensical configuration.
- `output-dir`: Repository-relative generated static-site directory. Default: `"site"`. It is used for cleanup, validation, and artifact upload and must agree with Zensical's configured `site_dir`.

### Build behavior

- `python-version`: Python version used to build the site. Default: `"3.13"`.
- `uv-version`: Optional UV version. Leave empty to use the `astral-sh/setup-uv` default.
- `clean`: Remove `output-dir` before building and pass `--clean` to Zensical. Default: `true`.
- `strict`: Pass `--strict` to Zensical, causing validation warnings to fail the build. Default: `true`.
- `build-flags`: Additional whitespace-delimited arguments passed to `zensical build`.
- `use-cache`: Enable UV dependency caching. Default: `true`.
- `cache-key-suffix`: Optional value used to separate dependency cache populations.
- `check-changed`: Enable relevant-path change detection before the build. Default: `false`.
- `changed-paths-mode`: How `changed-paths` is applied: `default`, `replace`, or `append`.
- `changed-paths`: Newline-delimited repository-relative Git pathspecs used when `changed-paths-mode` is `replace` or `append`.
- `checkout-ref`: Branch, tag, or commit SHA in the consuming repository to build. An empty value builds the triggering ref.
- `runner-image`: GitHub-hosted runner image or self-hosted runner label. Default: `"ubuntu-latest"`.
- `debug-state`: Print repository state, resolved paths, Zensical config, and tool versions. Default: `false`.

### Artifact handling

- `artifact-name`: Name of the uploaded static-site artifact. Default: `"zensical-site"`.
- `artifact-retention-days`: Number of days GitHub retains the artifact. Default: `7`.
- `artifact-if-no-files-found`: Behavior if the output directory is missing: `error`, `warn`, or `ignore`. Default: `"error"`.

## Outputs

- `zensical-changed`: Whether relevant Zensical paths changed when `check-changed` is enabled.
- `output-dir`: Absolute path of the generated static-site directory resolved by the shared action.

## Example use

This workflow is normally called by [`zensical-site-main`](../zensical-site-main/):

```yaml
---
name: Zensical Site Main Pipeline

on:
  workflow_call:
    inputs:
      artifact-name:
        required: false
        type: string
        default: "zensical-site"

      python-version:
        required: false
        type: string
        default: "3.13"

      working-directory:
        required: false
        type: string
        default: "."

      python-project-dir:
        required: false
        type: string
        default: "."

      zensical-config:
        required: false
        type: string
        default: ""

      docs-dir:
        required: false
        type: string
        default: ""

      output-dir:
        required: false
        type: string
        default: "site"

jobs:
  build-standard:
    uses: ./.github/workflows/zensical-build.yml@gh/zensical-build/vX.X.X
    with:
      python-version: ${{ inputs.python-version }}
      working-directory: ${{ inputs.working-directory }}
      python-project-dir: ${{ inputs.python-project-dir }}
      zensical-config: ${{ inputs.zensical-config }}
      docs-dir: ${{ inputs.docs-dir }}
      output-dir: ${{ inputs.output-dir }}
      clean: true
      strict: false
      use-cache: true
      artifact-name: ${{ inputs.artifact-name }}
      artifact-retention-days: 7
      artifact-if-no-files-found: "error"
      runner-image: ubuntu-latest
```

It can also be called independently from another repository:

```yaml
---
name: Build Zensical Site

on:
  pull_request:
    branches:
      - main
    paths:
      - "docs/**"
      - "docs-site/**"
      - "zensical.toml"

  workflow_dispatch:

permissions:
  contents: read
  actions: write

jobs:
  build:
    uses: redjax/pipelinetemplates/.github/workflows/zensical-build.yml@gh/zensical-build/vX.X.X
    with:
      python-version: "3.13"

      # Zensical config discovery and build run from repository root.
      working-directory: "."

      # UV dependencies and the Zensical executable are provided here.
      python-project-dir: "docs-site"

      zensical-config: "zensical.toml"
      docs-dir: "docs"
      output-dir: "docs-site/site"

      clean: true
      strict: true
      use-cache: true
      cache-key-suffix: "repository-docs"

      artifact-name: "repository-zensical-site"
      artifact-retention-days: 7
      artifact-if-no-files-found: "error"

      debug-state: false
```

For the layout above, the build stage is equivalent to:

```bash
uv run \
  --project docs-site \
  zensical build \
  --config-file zensical.toml \
  --clean \
  --strict
```
