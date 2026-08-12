# ShellCheck <!-- omit in toc -->

The [`shellcheck` reusable workflow](../../../../../.github/workflows/shellcheck.yml) runs [ShellCheck](https://github.com/koalaman/shellcheck) against shell scripts in a calling repository.

ShellCheck performs static analysis of Bash and supported POSIX-style shell scripts. It identifies common correctness, quoting, expansion, portability, and error-handling problems.

The workflow uses shared [`PipelineTemplates` scripts](../../../../../shared/scripts/ci-cd/quality/) and supports either a caller-owned `.shellcheckrc` file or the [central `PipelineTemplates` default configuration](../../../../../config/shellcheck/.shellcheckrc).

## Table of Contents <!-- omit in toc -->

- [Default behavior](#default-behavior)
- [Inputs](#inputs)
- [Configuration](#configuration)
  - [Central configuration](#central-configuration)
  - [Caller-owned configuration](#caller-owned-configuration)
  - [ShellCheck defaults](#shellcheck-defaults)
- [File selection](#file-selection)
- [Reports and policy](#reports-and-policy)
- [Permissions](#permissions)
- [Examples](#examples)
  - [Minimal scan](#minimal-scan)
  - [Scan a scripts directory](#scan-a-scripts-directory)
  - [Use caller configuration](#use-caller-configuration)
  - [Non-blocking baseline scan](#non-blocking-baseline-scan)

## Default behavior

With no caller-provided inputs, the workflow:

- Checks out the calling repository.
- Checks out `redjax/PipelineTemplates` at `pipelinetemplates-ref`.
- Installs ShellCheck.
- Scans shell files beneath `.`.
- Includes `*.sh`, `*.bash`, and `*.bats` files.
- Excludes common generated, dependency, and Git metadata directories.
- Uses the central `config/shellcheck/.shellcheckrc` configuration file.
- Writes ShellCheck output to a text report artifact.
- Fails when ShellCheck reports findings.
- Always fails when ShellCheck cannot install, configure, or execute successfully.

> [!NOTE]
> ShellCheck is a static-analysis tool. It reports shell-code issues but does not automatically rewrite scripts. Use the [`shellfmt`](../shellfmt/README.md) workflow to check or apply shell-script formatting. ShellCheck is designed to identify common bugs and portability problems in shell scripts.

## Inputs

| Input                           | Type      |                                          Default | Description                                                                               |
| ------------------------------- | --------- | -----------------------------------------------: | ----------------------------------------------------------------------------------------- |
| `pipelinetemplates-ref`         | `string`  |                                           `main` | Branch, tag, or commit SHA used to retrieve shared scripts and central configuration      |
| `scan-path`                     | `string`  |                                              `.` | Repository-relative file or directory to scan                                             |
| `shellcheck-version`            | `string`  |               (passed from consuming repository) | ShellCheck release version to install, without a leading `v`                              |
| `include-patterns`              | `string`  |                             `*.sh,*.bash,*.bats` | Comma-separated shell-file patterns to include                                            |
| `exclude-paths`                 | `string`  | `.git,node_modules,vendor,dist,build,.terraform` | Comma-separated files or directories to exclude                                           |
| `shellcheck-config-path`        | `string`  |                                            Empty | Optional repository-relative caller-owned ShellCheck configuration path                   |
| `use-default-shellcheck-config` | `boolean` |                                           `true` | Use PipelineTemplates `config/shellcheck/.shellcheckrc` when no caller config is supplied |
| `fail-on-findings`              | `boolean` |                                           `true` | Fail when ShellCheck reports findings                                                     |
| `artifact-name`                 | `string`  |                             `shellcheck-results` | Uploaded report artifact name                                                             |
| `artifact-retention-days`       | `number`  |                                             `30` | Number of days to retain the report artifact                                              |

## Configuration

The workflow resolves ShellCheck configuration in this order:

1. A caller-supplied `shellcheck-config-path`.
2. The central PipelineTemplates configuration file.
3. ShellCheck defaults, when both caller and central configuration are disabled.

### Central configuration

The central default configuration is stored in:

```text
config/shellcheck/.shellcheckrc
```

Use the central default by leaving `shellcheck-config-path` empty:

```yaml
with:
  use-default-shellcheck-config: true
```

### Caller-owned configuration

A consuming repository can supply its own configuration file:

```yaml
with:
  shellcheck-config-path: ".shellcheckrc"
  use-default-shellcheck-config: false
```

The configuration path is relative to the calling repository root.

### ShellCheck defaults

Disable both configuration sources to run ShellCheck using its built-in defaults:

```yaml
with:
  shellcheck-config-path: ""
  use-default-shellcheck-config: false
```

## File selection

By default, the workflow scans:

```text
*.sh
*.bash
*.bats
```

The workflow searches recursively beneath `scan-path`.

Restrict scanning to a scripts directory:

```yaml
with:
  scan-path: scripts
```

Include additional file extensions:

```yaml
with:
  include-patterns: "*.sh,*.bash,*.bats,*.command"
```

Exclude generated content or vendored dependencies only when justified:

```yaml
with:
  exclude-paths: ".git,node_modules,vendor,dist,build,.terraform,third_party"
```

## Reports and policy

The workflow writes ShellCheck output to:

```text
shellcheck.txt
```

It uploads the report as an artifact named:

```text
shellcheck-results
```

A caller can provide a unique artifact name when multiple ShellCheck workflow calls run in the same workflow execution:

```yaml
with:
  artifact-name: service-a-shellcheck-results
```

The workflow distinguishes ordinary ShellCheck findings from execution failures:

| Outcome                                         |  Exit behavior | Workflow behavior                              |
| ----------------------------------------------- | -------------: | ---------------------------------------------- |
| No findings                                     |            `0` | Succeeds                                       |
| Findings with `fail-on-findings: true`          |            `1` | Uploads report, then fails                     |
| Findings with `fail-on-findings: false`         |            `1` | Uploads report, emits a warning, then succeeds |
| Installation, configuration, or runtime failure | `2` or greater | Fails regardless of `fail-on-findings`         |

Use `fail-on-findings: false` only for baseline creation, intentional test fixtures, or a staged adoption period.

## Permissions

ShellCheck only reads repository content:

```yaml
permissions:
  contents: read
```

No write permission is required.

## Examples

### Minimal scan

```yaml
---
name: ShellCheck

on:
  pull_request:
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read

jobs:
  shellcheck:
    uses: redjax/PipelineTemplates/.github/workflows/shellcheck.yml@v1
    with:
      pipelinetemplates-ref: v1
```

### Scan a scripts directory

```yaml
jobs:
  shellcheck:
    uses: redjax/PipelineTemplates/.github/workflows/shellcheck.yml@v1
    with:
      pipelinetemplates-ref: v1
      scan-path: scripts
      fail-on-findings: true
```

### Use caller configuration

```yaml
jobs:
  shellcheck:
    uses: redjax/PipelineTemplates/.github/workflows/shellcheck.yml@v1
    with:
      pipelinetemplates-ref: v1
      scan-path: scripts
      shellcheck-config-path: ".shellcheckrc"
      use-default-shellcheck-config: false
      fail-on-findings: true
```

### Non-blocking baseline scan

```yaml
jobs:
  shellcheck:
    uses: redjax/PipelineTemplates/.github/workflows/shellcheck.yml@v1
    with:
      pipelinetemplates-ref: v1
      scan-path: .
      fail-on-findings: false
      artifact-name: shellcheck-baseline-results
```

Review the report artifact, remediate or intentionally suppress valid exceptions, then enable enforcement.
