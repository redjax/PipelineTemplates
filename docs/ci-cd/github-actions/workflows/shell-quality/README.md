# Shell Quality <!-- omit in toc -->

The [`shell-quality` reusable workflow](../../../../../.github/workflows/shell-quality.yml) orchestrates the centralized `shellcheck` and `shellfmt` reusable workflows.

Use this workflow when a repository wants one reusable workflow call that runs `shellcheck`, `shellfmt`, or both. Repositories can also call [`shellcheck`](../shellcheck/README.md) and [`shellfmt`](../shellfmt/README.md) independently when they need separate jobs or different policies.

The orchestrator does not install tools, discover files, resolve configuration, create reports, or enforce tool-specific policy itself. Those responsibilities remain in the individual reusable workflows.

## Table of Contents <!-- omit in toc -->

- [Default behavior](#default-behavior)
- [Tool selection](#tool-selection)
- [Inputs](#inputs)
- [Configuration](#configuration)
  - [Central defaults](#central-defaults)
  - [Caller-owned configuration](#caller-owned-configuration)
- [Formatting commits](#formatting-commits)
- [Artifacts](#artifacts)
- [Permissions](#permissions)
- [Examples](#examples)
  - [Minimal shell-quality gate](#minimal-shell-quality-gate)
  - [ShellCheck only](#shellcheck-only)
  - [shellfmt only](#shellfmt-only)
  - [Both tools with caller configuration](#both-tools-with-caller-configuration)
  - [Automatically format internal PRs](#automatically-format-internal-prs)
  - [Immutable release pinning](#immutable-release-pinning)

## Default behavior

With no caller-provided inputs, the workflow:

- Validates the requested tool selection.
- Runs both `shellcheck` and `shellfmt` (in `check` mode).
- Scans shell files beneath `.`.
- Uses PipelineTemplates default `shellcheck` and `shellfmt` configuration.
- Fails when either selected tool reports findings.
- Uploads independent `shellcheck` and `shellfmt` report artifacts.

The default is a strict shell quality gate that does not rewrite files, but fails the pipeline when findings are detected.

## Tool selection

Set `tools` to choose which underlying reusable workflows run:

| Value        | Behavior                                     |
| ------------ | -------------------------------------------- |
| `shellcheck` | Runs only the `shellcheck` reusable workflow |
| `shellfmt`   | Runs only the `shellfmt` reusable workflow   |
| `both`       | Runs `shellcheck` and `shellfmt` in parallel |

Examples:

```yaml
with:
  tools: shellcheck
```

```yaml
with:
  tools: shellfmt
```

```yaml
with:
  tools: both
```

The default is:

```yaml
tools: both
```

## Inputs

| Input                           | Type      |                                            Default | Description                                                                                                    |
| ------------------------------- | --------- | -------------------------------------------------: | -------------------------------------------------------------------------------------------------------------- |
| `pipelinetemplates-ref`         | `string`  |                                             `main` | PipelineTemplates branch, tag, or commit SHA containing reusable workflows, scripts, and central configuration |
| `tools`                         | `string`  |                                             `both` | Tools to run: `shellcheck`, `shellfmt`, or `both`                                                              |
| `scan-path`                     | `string`  |                                                `.` | Repository-relative file or directory to scan                                                                  |
| `include-patterns`              | `string`  |                               `*.sh,*.bash,*.bats` | Comma-separated shell-file patterns to include                                                                 |
| `exclude-paths`                 | `string`  |   `.git,node_modules,vendor,dist,build,.terraform` | Comma-separated files or directories to exclude                                                                |
| `shellcheck-config-path`        | `string`  |                                              Empty | Optional repository-relative caller-owned `shellcheck` configuration path                                      |
| `use-default-shellcheck-config` | `boolean` |                                             `true` | Use PipelineTemplates default `shellcheck` configuration                                                       |
| `shellfmt-config-path`          | `string`  |                                              Empty | Optional repository-relative caller-owned `shellfmt` options-file path                                         |
| `use-default-shellfmt-config`   | `boolean` |                                             `true` | Use PipelineTemplates default `shellfmt` options                                                               |
| `shellcheck-version`            | `string`  |                                           `0.10.0` | `shellcheck` version to install                                                                                |
| `shellfmt-version`              | `string`  |                                           `3.10.0` | `shellfmt` version to install                                                                                  |
| `shellfmt-mode`                 | `string`  |                                            `check` | `shellfmt` mode: `check` or `write`                                                                            |
| `shellfmt-commit-changes`       | `boolean` |                                            `false` | Commit `shellfmt` changes back to an internal pull request branch                                              |
| `shellfmt-commit-message`       | `string`  | `style(shell): format shell scripts with shellfmt` | Commit message for automated `shellfmt` commits                                                                |
| `fail-on-findings`              | `boolean` |                                             `true` | Fail selected tool jobs when findings exist                                                                    |
| `shellcheck-artifact-name`      | `string`  |                               `shellcheck-results` | `shellcheck` report artifact name                                                                              |
| `shellfmt-artifact-name`        | `string`  |                                 `shellfmt-results` | `shellfmt` report artifact name                                                                                |
| `artifact-retention-days`       | `number`  |                                               `30` | Number of days to retain report artifacts                                                                      |

## Configuration

The orchestrator forwards tool-specific configuration inputs to the selected individual reusable workflows.

### Central defaults

By default, the workflow uses:

```text
config/shellcheck/.shellcheckrc
config/shellfmt/options
```

This caller uses both central defaults:

```yaml
with:
  tools: both
  use-default-shellcheck-config: true
  use-default-shellfmt-config: true
```

### Caller-owned configuration

A repository can provide one custom config and retain the central default for the other tool:

```yaml
with:
  tools: both

  shellcheck-config-path: ".shellcheckrc"
  use-default-shellcheck-config: false

  use-default-shellfmt-config: true
```

A repository can provide custom configuration for both tools:

```yaml
with:
  tools: both

  shellcheck-config-path: ".shellcheckrc"
  use-default-shellcheck-config: false

  shellfmt-config-path: ".shellfmt-options"
  use-default-shellfmt-config: false
```

## Formatting commits

The orchestrator forwards `shellfmt` write-mode inputs to the `shellfmt` reusable workflow.

Use this configuration to automatically format scripts and commit the changes back to an internal pull request:

```yaml
with:
  tools: both

  shellfmt-mode: write
  shellfmt-commit-changes: true
  shellfmt-commit-message: "style(shell): format shell scripts with shellfmt"
```

> [!NOTE]
> Automatic commits are allowed only for pull requests whose source branch belongs to the same repository. The workflow does not push changes to fork pull requests.

`shellcheck` remains a quality gate in write mode. `shellfmt` can rewrite formatting, but `shellcheck` findings still require developer remediation or an intentional repository-local suppression.

## Artifacts

The orchestrator creates independent artifacts through the individual workflows:

| Tool         | Default artifact     | Report           |
| ------------ | -------------------- | ---------------- |
| `shellcheck` | `shellcheck-results` | `shellcheck.txt` |
| `shellfmt`   | `shellfmt-results`   | `shellfmt.diff`  |

When invoking the orchestrator multiple times in one workflow execution, provide unique artifact names:

```yaml
with:
  shellcheck-artifact-name: service-a-shellcheck-results
  shellfmt-artifact-name: service-a-shellfmt-results
```

## Permissions

For normal linting and formatting checks:

```yaml
permissions:
  contents: read
```

For `shellfmt` write mode with automatic commits to internal pull requests:

```yaml
permissions:
  contents: write
```

The calling workflow controls permissions. The orchestrator and nested reusable workflows cannot grant themselves more permission than the caller supplies.

## Examples

### Minimal shell-quality gate

```yaml
---
name: Shell Quality

on:
  pull_request:
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read

jobs:
  shell-quality:
    uses: redjax/PipelineTemplates/.github/workflows/shell-quality.yml@main
    with:
      pipelinetemplates-ref: main
```

### ShellCheck only

```yaml
jobs:
  shellcheck:
    uses: redjax/PipelineTemplates/.github/workflows/shell-quality.yml@main
    with:
      pipelinetemplates-ref: main
      tools: shellcheck
      scan-path: scripts
      fail-on-findings: true
```

### shellfmt only

```yaml
jobs:
  shellfmt:
    uses: redjax/PipelineTemplates/.github/workflows/shell-quality.yml@main
    with:
      pipelinetemplates-ref: main
      tools: shellfmt
      scan-path: scripts
      shellfmt-mode: check
      fail-on-findings: true
```

### Both tools with caller configuration

```yaml
jobs:
  shell-quality:
    uses: redjax/PipelineTemplates/.github/workflows/shell-quality.yml@main
    with:
      pipelinetemplates-ref: main
      tools: both
      scan-path: scripts

      shellcheck-config-path: ".shellcheckrc"
      use-default-shellcheck-config: false

      shellfmt-config-path: ".shellfmt-options"
      use-default-shellfmt-config: false

      fail-on-findings: true
```

### Automatically format internal PRs

```yaml
---
name: Shell Quality

on:
  pull_request:
    paths:
      - "**/*.sh"
      - "**/*.bash"
      - "**/*.bats"
      - ".github/workflows/shell-quality.yml"

permissions:
  contents: write

jobs:
  shell-quality:
    uses: redjax/PipelineTemplates/.github/workflows/shell-quality.yml@main
    with:
      pipelinetemplates-ref: main
      tools: both
      scan-path: scripts

      shellfmt-mode: write
      shellfmt-commit-changes: true
      shellfmt-commit-message: "style(shell): format shell scripts with shellfmt"

      fail-on-findings: true
```

### Immutable release pinning

For the strongest reproducibility, pin both references to the same immutable commit SHA:

```yaml
jobs:
  shell-quality:
    uses: redjax/PipelineTemplates/.github/workflows/shell-quality.yml@<commit-sha>
    with:
      pipelinetemplates-ref: <commit-sha>
      tools: both
      fail-on-findings: true
```
