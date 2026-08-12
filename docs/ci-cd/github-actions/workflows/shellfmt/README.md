# shellfmt <!-- omit in toc -->

The [`shellfmt` reusable workflow](../../../../../.github/workflows/shellfmt.yml) checks or formats shell scripts in a calling repository using [shellfmt](https://github.com/mvdan/sh).

The workflow supports `check` mode for normal CI enforcement and `write` mode for internal pull requests. In `write` mode, `shellfmt` can rewrite unformatted files and commit the changes back to the pull request source branch.

The workflow uses either a caller-owned `shellfmt` options file or the [central `PipelineTemplates` default options file](../../../../../config/shellfmt/options).

## Table of Contents <!-- omit in toc -->

- [Default behavior](#default-behavior)
- [Inputs](#inputs)
- [Modes](#modes)
  - [Check mode](#check-mode)
  - [Write mode](#write-mode)
- [Configuration](#configuration)
  - [Central configuration](#central-configuration)
  - [Caller-owned configuration](#caller-owned-configuration)
  - [No configuration](#no-configuration)
- [File selection](#file-selection)
- [Reports and policy](#reports-and-policy)
- [Permissions](#permissions)
- [Examples](#examples)
  - [Minimal formatting check](#minimal-formatting-check)
  - [Check a scripts directory](#check-a-scripts-directory)
  - [Use caller shellfmt options](#use-caller-shellfmt-options)
  - [Automatically format internal PRs](#automatically-format-internal-prs)

## Default behavior

With no caller-provided inputs, the workflow:

- Checks out the calling repository.
- Checks out `redjax/PipelineTemplates` at `pipelinetemplates-ref`.
- Installs shellfmt.
- Scans shell files beneath `.`.
- Includes `*.sh`, `*.bash`, and `*.bats` files.
- Uses the central `config/shellfmt/options` file.
- Runs in `check` mode.
- Writes a formatting diff report artifact.
- Fails when formatting differences are found.
- Always fails when shellfmt cannot install, configure, or execute successfully.

> [!NOTE]
> `shellfmt` is responsible for shell-script formatting. In `check` mode, it reports formatting differences without changing repository files. In `write` mode, it rewrites files in the GitHub Actions checkout.

## Inputs

| Input                         | Type      |                                            Default | Description                                                                                       |
| ----------------------------- | --------- | -------------------------------------------------: | ------------------------------------------------------------------------------------------------- |
| `pipelinetemplates-ref`       | `string`  |                                             `main` | Branch, tag, or commit SHA used to retrieve shared scripts and central configuration              |
| `scan-path`                   | `string`  |                                                `.` | Relative file or directory to scan                                                                |
| `shellfmt-version`            | `string`  |                 (provided by consuming repository) | `shellfmt` release version to install, without a leading `v`                                      |
| `include-patterns`            | `string`  |                               `*.sh,*.bash,*.bats` | Comma-separated shell-file patterns to include                                                    |
| `exclude-paths`               | `string`  |   `.git,node_modules,vendor,dist,build,.terraform` | Comma-separated files or directories to exclude                                                   |
| `shellfmt-config-path`        | `string`  |                                              Empty | Optional relative path to caller-owned `shellfmt` options-file path                               |
| `use-default-shellfmt-config` | `boolean` |                                             `true` | Use PipelineTemplates `config/shellfmt/options` when no caller config is supplied                 |
| `mode`                        | `string`  |                                            `check` | `check` reports formatting differences; `write` formats the runner checkout                       |
| `fail-on-findings`            | `boolean` |                                             `true` | Fail on formatting differences in `check` mode                                                    |
| `commit-changes`              | `boolean` |                                            `false` | Commit `shellfmt` changes back to an internal PR source branch; requires `mode: write` permission |
| `commit-message`              | `string`  | `style(shell): format shell scripts with shellfmt` | Commit message for automated formatting commits                                                   |
| `artifact-name`               | `string`  |                                 `shellfmt-results` | Uploaded report artifact name                                                                     |
| `artifact-retention-days`     | `number`  |                                               `30` | Number of days to retain the report artifact                                                      |

## Modes

### Check mode

Check mode is the normal CI quality-gate mode:

```yaml
with:
  mode: check
  fail-on-findings: true
```

The workflow runs `shellfmt` in diff mode. It does not modify the caller repository.

When differences exist, the workflow uploads a diff report and fails after report publication.

Use `check` mode for:

- Pull-request validation when automatic formatting is not desired.
- Push, schedule, and manual workflows.
- Fork pull requests.
- Repositories that require developers to own formatting commits.

### Write mode

Write mode formats matching files in the runner checkout:

```yaml
with:
  mode: write
```

The runner checkout is temporary. Formatting changes disappear when the job ends unless the workflow commits them.

Use `write` mode with `commit-changes: true` to persist formatting changes to an internal pull request:

```yaml
with:
  mode: write
  commit-changes: true
```

The workflow only permits automatic commits when all of the following are true:

- The event is `pull_request`.
- The pull request source repository is the same repository as the target repository.
- The caller enables `commit-changes`.
- The caller grants `contents: write`.
- shellfmt completes successfully.

Fork pull requests are intentionally rejected for automatic formatting commits.

## Configuration

`shellfmt` does not use a standard `.shellfmtrc` convention. `PipelineTemplates` uses a simple options-file convention:

```text
config/shellfmt/options
```

Each non-comment line is passed to shellfmt as one argument.

For example:

```text
# Indent with two spaces.
-i
2

# Indent case branches.
-ci

# Apply redirect formatting.
-sr
```

### Central configuration

Use the central default options file:

```yaml
with:
  use-default-shellfmt-config: true
```

### Caller-owned configuration

A consuming repository can provide its own options file:

```yaml
with:
  shellfmt-config-path: ".shellfmt-options"
  use-default-shellfmt-config: false
```

The file path is relative to the calling repository root.

### No configuration

Run `shellfmt` with built-in behavior only:

```yaml
with:
  shellfmt-config-path: ""
  use-default-shellfmt-config: false
```

## File selection

By default, the workflow scans:

```text
*.sh
*.bash
*.bats
```

It searches recursively beneath `scan-path`.

Scan a repository scripts directory:

```yaml
with:
  scan-path: scripts
```

Add additional extensions:

```yaml
with:
  include-patterns: "*.sh,*.bash,*.bats,*.command"
```

Exclude generated or vendored paths when required:

```yaml
with:
  exclude-paths: ".git,node_modules,vendor,dist,build,.terraform,third_party"
```

## Reports and policy

The workflow creates:

```text
shellfmt.diff
```

In `check` mode, this contains a unified diff for files that do not match configured formatting.

In `write` mode, the report lists files that required formatting before `shellfmt` rewrote them.

The report artifact defaults to:

```text
shellfmt-results
```

Use a unique artifact name when multiple `shellfmt` calls run in one workflow execution:

```yaml
with:
  artifact-name: payments-shellfmt-results
```

The workflow handles outcomes as follows:

| Mode        | Outcome                                           | Workflow behavior                            |
| ----------- | ------------------------------------------------- | -------------------------------------------- |
| `check`     | No differences                                    | Succeeds                                     |
| `check`     | Differences and `fail-on-findings: true`          | Uploads report, then fails                   |
| `check`     | Differences and `fail-on-findings: false`         | Uploads report, emits warning, then succeeds |
| `write`     | No files require formatting                       | Succeeds                                     |
| `write`     | Files reformatted successfully                    | Succeeds; optionally commits changes         |
| Either mode | Installation, configuration, or execution failure | Fails regardless of `fail-on-findings`       |

## Permissions

Check-only callers require read access:

```yaml
permissions:
  contents: read
```

Callers that use `write` mode with automatic pull-request commits require:

```yaml
permissions:
  contents: write
```

The reusable workflow does not elevate permissions. The calling workflow must explicitly grant the required permission level.

Also ensure the consuming repository allows GitHub Actions workflows to receive write-capable `GITHUB_TOKEN` permissions.

## Examples

### Minimal formatting check

```yaml
---
name: shellfmt

on:
  pull_request:
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read

jobs:
  shellfmt:
    uses: redjax/PipelineTemplates/.github/workflows/shellfmt.yml@main
    with:
      pipelinetemplates-ref: main
```

### Check a scripts directory

```yaml
jobs:
  shellfmt:
    uses: redjax/PipelineTemplates/.github/workflows/shellfmt.yml@main
    with:
      pipelinetemplates-ref: main
      scan-path: scripts
      mode: check
      fail-on-findings: true
```

### Use caller shellfmt options

```yaml
jobs:
  shellfmt:
    uses: redjax/PipelineTemplates/.github/workflows/shellfmt.yml@main
    with:
      pipelinetemplates-ref: main
      scan-path: scripts
      shellfmt-config-path: ".shellfmt-options"
      use-default-shellfmt-config: false
      mode: check
      fail-on-findings: true
```

### Automatically format internal PRs

```yaml
---
name: Format Shell Scripts

on:
  pull_request:
    paths:
      - "**/*.sh"
      - "**/*.bash"
      - "**/*.bats"
      - ".github/workflows/shellfmt.yml"

permissions:
  contents: write

jobs:
  shellfmt:
    uses: redjax/PipelineTemplates/.github/workflows/shellfmt.yml@main
    with:
      pipelinetemplates-ref: main
      scan-path: scripts

      mode: write
      commit-changes: true
      commit-message: "style(shell): format shell scripts with shellfmt"

      fail-on-findings: true
```

When formatting is required on an internal pull request, the workflow commits the changes to the pull-request source branch. Pushing to a pull request branch updates the existing pull request.
