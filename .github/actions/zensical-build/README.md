# GitHub Action: Zensical Build

This action builds a [Zensical](https://zensical.org/) static documentation site with [UV](https://docs.astral.sh/uv)-managed Python dependencies, optional dependency caching, optional changed-path detection, build-output validation, and workflow artifact publishing.

It is designed for both simple Zensical repositories and split layouts where:

- The Zensical configuration file is at the repository root or elsewhere.
- The docs content directory is separate from the Python/UV project.
- The UV project containing pyproject.toml and uv.lock is nested, such as docs-site/.
- The generated site is written to a configured output directory, such as site/, docs-site/site/, or dist/.

The action runs Zensical through UV:

```bash
uv run --project <python-project-dir> zensical build
```

Zensical configuration controls settings such as `docs_dir` and `site_dir`. The action’s `docs-dir` and `output-dir` inputs provide validation, cleanup, changed-path detection, and artifact-upload paths; when supplied, they must agree with the corresponding configuration values. Zensical builds static output into its configured `site_dir`, which defaults to `site`.

## Requirements

The consuming repository must provide:

- Python project directory containing a `pyproject.toml`.
- Zensical declared as a project dependency or otherwise available to `uv run`.
- Optionally, a `uv.lock` file for deterministic dependency installation.
- A Zensical configuration file such as `zensical.toml`, unless the project relies on Zensical’s configuration discovery.
- Documentation source files at the location configured through Zensical’s `docs_dir` setting or defaults.

The action installs the requested Python version, installs UV, runs `uv sync`, then invokes the Zensical build command. When `uv.lock` exists, the action runs `uv sync --locked` so CI validates and uses the committed lockfile.

## Inputs

### Runtime and project inputs

| Input              | Default | Description                                                                                                                                                       |
| ------------------ | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| python-version     | 3.13    | Python version installed for the build.                                                                                                                           |
| uv-version         | ""      | Optional UV version. Leave empty to use the setup action default.                                                                                                 |
| working-directory  | .       | Repository-relative directory from which Zensical is executed and configuration discovery occurs.                                                                 |
| python-project-dir | .       | Repository-relative directory containing the UV project pyproject.toml and optional uv.lock.                                                                      |
| zensical-config    | ""      | Optional repository-relative path to a Zensical config file. Leave empty to rely on Zensical’s normal config discovery.                                           |
| docs-dir           | ""      | Optional repository-relative docs-source directory. Used for validation and changed-path detection. It must match docs_dir from the selected Zensical config.     |
| output-dir         | site    | Repository-relative generated static-site directory. Used for cleanup, validation, and artifact upload. It must match site_dir from the selected Zensical config. |

### Build inputs

| Input       | Default | Description                                                                           |
| ----------- | ------- | ------------------------------------------------------------------------------------- |
| clean       | true    | Remove output-dir before build and pass --clean to zensical build.                    |
| strict      | false   | Pass --strict to Zensical, causing warnings to fail the build.                        |
| build-flags | ""      | Additional whitespace-delimited arguments appended to zensical build.                 |
| debug-state | false   | Print resolved paths, Git state, tool versions, project contents, and config content. |

### Caching inputs

| Input            | Default | Description                                                                             |
| ---------------- | ------- | --------------------------------------------------------------------------------------- |
| use-cache        | true    | Enable UV dependency caching through astral-sh/setup-uv.                                |
| cache-key-suffix | ""      | Optional value for separating cache populations, such as docs, staging, or a site name. |

### Change detection inputs

| Input              | Default | Description                                                                                         |
| ------------------ | ------- | --------------------------------------------------------------------------------------------------- |
| check-changed      | false   | Determine whether relevant files changed between HEAD~1 and HEAD; skip the build when they did not. |
| changed-paths-mode | default | Controls application of changed-paths: default, replace, or append.                                 |
| changed-paths      | ""      | Newline-delimited repository-relative Git pathspecs used with replace or append.                    |

Default tracked paths include:

- The full working-directory tree.
- `<python-project-dir>/pyproject.toml`.
- `<python-project-dir>/uv.lock`.
- The supplied Zensical config file, when `zensical-config` is set.
- The supplied docs directory tree, when `docs-dir` is set.

### Artifact inputs

| Input                      | Default       | Description                                                     |
| -------------------------- | ------------- | --------------------------------------------------------------- |
| publish-artifact           | false         | Upload the generated static site as a workflow artifact.        |
| artifact-name              | zensical-site | Artifact name used by actions/upload-artifact.                  |
| artifact-retention-days    | 7             | Number of days GitHub retains the uploaded artifact.            |
| artifact-if-no-files-found | error         | Behavior if artifact files are missing: error, warn, or ignore. |

### Outputs

| Output           | Description                                                                                                                   |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| zensical-changed | Whether relevant configured Zensical files changed. Only populated when check-changed: "true" is enabled.                     |
| output-dir       | Absolute resolved path to the expected Zensical-generated static-site directory.                                              |
| should-build     | Whether the action should run a build. This is primarily informational; the action controls the conditional build internally. |

## Usage

### Flat repository

Example layout:

```text
.
├── docs/
├── site/
├── pyproject.toml
├── uv.lock
└── zensical.toml
```

Example workflow:

```yaml
---
name: Build Zensical Documentation

on:
  workflow_dispatch:
  pull_request:
  push:
    branches:
      - main

permissions:
  contents: read
  actions: write

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v7
        with:
          fetch-depth: 0

      - name: Build Zensical site
        uses: redjax/pipelinetemplates/.github/actions/zensical-build@<pinned-ref>
        with:
          python-version: "3.13"
          working-directory: "."
          python-project-dir: "."
          zensical-config: "zensical.toml"
          docs-dir: "docs"
          output-dir: "site"
          clean: "true"
          strict: "true"
          use-cache: "true"
          publish-artifact: "true"
          artifact-name: "zensical-site"
```

This executes the equivalent command:

```bash
uv run --project . zensical build \
  --config-file <repository-root>/zensical.toml \
  --clean \
  --strict
```

### Separate docs-site Python project

This layout matches the `pipelinetemplates` repository pattern:

```text
.
├── docs/
├── docs-site/
│   ├── pyproject.toml
│   ├── uv.lock
│   └── site/
└── zensical.toml
```

Example workflow:

```yaml
---
name: Build PipelineTemplates Documentation

on:
  workflow_dispatch:

permissions:
  contents: read
  actions: write

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v7
        with:
          fetch-depth: 0

      - name: Build Zensical documentation
        uses: redjax/pipelinetemplates/.github/actions/zensical-build@<pinned-ref>
        with:
          python-version: "3.13"

          ## Zensical runs at repository root, where zensical.toml lives.
          working-directory: "."

          ## UV uses docs-site/pyproject.toml and docs-site/uv.lock.
          python-project-dir: "docs-site"

          ## These paths agree with the repository Zensical configuration.
          zensical-config: "zensical.toml"
          docs-dir: "docs"
          output-dir: "docs-site/site"

          clean: "true"
          strict: "true"

          use-cache: "true"
          cache-key-suffix: "pipelinetemplates-docs"

          publish-artifact: "true"
          artifact-name: "pipelinetemplates-zensical-site"
          artifact-retention-days: "7"
```

This maps to the local build model:

```bash
cd <repository-root>

uv sync --locked \
  --project docs-site

uv run \
  --project docs-site \
  zensical build \
  --config-file <repository-root>/zensical.toml \
  --clean \
  --strict
```

The action expects the finished static site at `docs-site/site/`

### Use Zensical discovery

If the repository uses the conventional project layout and Zensical’s built-in configuration discovery, omit `zensical-config`:

```yaml
---
- name: Build Zensical site
  uses: redjax/pipelinetemplates/.github/actions/zensical-build@<pinned-ref>
  with:
    working-directory: "."
    python-project-dir: "."
    docs-dir: "docs"
    output-dir: "site"
    clean: "true"
    publish-artifact: "true"
```

The resulting build command does not include `--config-file`:

```bash
uv run --project . zensical build --clean
```

### Strict build with extra flags

Use `strict: "true"` to fail the pipeline when Zensical emits warnings:

```yaml
---
- name: Build Zensical site strictly
  uses: redjax/pipelinetemplates/.github/actions/zensical-build@<pinned-ref>
  with:
    zensical-config: "zensical.toml"
    docs-dir: "docs"
    output-dir: "site"
    strict: "true"
```

For other supported Zensical build arguments, use `build-flags`:

```yaml
---
- name: Build Zensical site with extra arguments
  uses: redjax/pipelinetemplates/.github/actions/zensical-build@<pinned-ref>
  with:
    zensical-config: "zensical.toml"
    docs-dir: "docs"
    output-dir: "site"
    build-flags: "--no-directory-urls"
```

Use only flags supported by the Zensical version pinned in the consuming project’s dependencies. The action passes these as whitespace-delimited command arguments.

## Change detection

For a documentation-heavy repository, enable change detection to avoid building when a commit changes unrelated files:

```yaml
---
- name: Build Zensical site when documentation changes
  uses: redjax/pipelinetemplates/.github/actions/zensical-build@<pinned-ref>
  with:
    working-directory: "."
    python-project-dir: "docs-site"
    zensical-config: "zensical.toml"
    docs-dir: "docs"
    output-dir: "docs-site/site"

    check-changed: "true"
    changed-paths-mode: "append"
    changed-paths: |
      README.md
      .github/workflows/**
      shared/templates/**

    publish-artifact: "true"
    artifact-name: "zensical-site"
```

Modes behave as follows:

| Mode    | Behavior                                                                                        |
| ------- | ----------------------------------------------------------------------------------------------- |
| default | Check the action’s standard Zensical, docs, config, and dependency paths. Ignore changed-paths. |
| replace | Check only changed-paths.                                                                       |
| append  | Check the standard paths and changed-paths.                                                     |

When no parent commit is available, such as a shallow or initial-history situation, the action builds rather than incorrectly deciding there were no documentation changes.

## Zensical path handling

The action supports independent locations for:

```text
working-directory
python-project-dir
zensical-config
docs-dir
output-dir
```

This is important for repositories where the Zensical configuration and documentation are kept near the repository root but the Python project is isolated under a directory such as docs-site/.

For example:

```text
.
├── config/
│   └── zensical.toml
├── documentation/
├── tooling/
│   └── docs-python/
│       ├── pyproject.toml
│       └── uv.lock
└── generated/
    └── docs-site/
```

The action can be called as:

```yaml
---
- name: Build split-layout Zensical site
  uses: redjax/pipelinetemplates/.github/actions/zensical-build@<pinned-ref>
  with:
    working-directory: "."
    python-project-dir: "tooling/docs-python"
    zensical-config: "config/zensical.toml"
    docs-dir: "documentation"
    output-dir: "generated/docs-site"
    clean: "true"
    publish-artifact: "true"
```

The values of `docs-dir` and `output-dir` must match the paths Zensical resolves from its selected config. The action does not try to force these values using unsupported command-line switches.

## Notes

- `working-directory` controls where `zensical build` executes and where Zensical performs automatic configuration discovery.
- `python-project-dir` controls which `pyproject.toml`, `uv.lock`, `dependencies`, and Zensical executable UV uses.
- `zensical-config` is optional. If supplied, the action uses Zensical’s `--config-file` option.
- `docs-dir` is optional but recommended when the docs content is not trivially located. It improves validation and change detection.
- `output-dir` defaults to `site`, matching Zensical’s normal build-output default. It must be inside `$GITHUB_WORKSPACE`; this prevents clean builds from removing paths outside the checked-out repository.
- `clean: "true"` both removes the action’s configured `output-dir` and supplies `--clean` to Zensical.
- `strict: "true"` is recommended for protected-branch builds once the documentation is warning-free.
- The generated artifact is the raw static-site directory, suitable for later download by GitHub Releases, GitHub Pages, Cloudflare Pages, or branch-publishing workflows.
- Pin the action to a release tag or full commit SHA once it is published. During development, a feature branch ref is acceptable for temporary integration testing.
