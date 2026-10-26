# Validate PowerShell <!-- omit in toc -->

The [`validate-powershell` reusable workflow](../../../../../.github/workflows/validate-powershell.yml) runs PowerShell linting and formatting checks in a calling repository. It combines the [`powershell-lint`](../powershell-lint/README.md) and [`powershell-format`](../powershell-format/README.md) workflows without duplicating their implementation.

Each operation runs in an independent job with its own checkout, configuration selection, reporting, and enforcement policy.

## Table of Contents <!-- omit in toc -->

- [Default behavior](#default-behavior)
- [Inputs](#inputs)
- [Configuration](#configuration)
- [File selection](#file-selection)
- [Linting and formatting jobs](#linting-and-formatting-jobs)
- [Reports and policy](#reports-and-policy)
- [Permissions](#permissions)
- [Examples](#examples)
  - [Validate pull requests to main](#validate-pull-requests-to-main)
  - [Use repository settings](#use-repository-settings)
  - [Non-blocking baseline validation](#non-blocking-baseline-validation)
  - [Scan selected folders](#scan-selected-folders)
  - [Manual validation with optional formatting fixes](#manual-validation-with-optional-formatting-fixes)

## Default behavior

With no caller-provided inputs, the workflow:

- Runs both linting and formatting.
- Checks tracked `.ps1`, `.psm1`, and `.psd1` files throughout the calling repository.
- Applies no additional path exclusions.
- Uses [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) for both operations.
- Discovers repository-root lint and formatter settings independently.
- Uses the corresponding central fallback when a repository-local file is absent.
- Reports lint warnings and errors.
- Checks formatting without modifying files.
- Fails on lint findings.
- Fails on formatting differences.
- Always fails an affected job when installation, configuration, or execution fails.

> [!NOTE]
> This workflow always runs both operations. To run only linting or only formatting, call the corresponding individual workflow.

## Inputs

| Input                      | Type      | Default                   | Description                                                                                  |
| -------------------------- | --------- | ------------------------- | -------------------------------------------------------------------------------------------- |
| `paths`                    | `string`  | `.`                       | Files or folders to check, one per line                                                      |
| `exclude-paths`            | `string`  | Empty                     | Files or folders to skip, one wildcard pattern per line                                      |
| `lint-settings-file`       | `string`  | Empty                     | Path to repository-owned lint settings                                                       |
| `format-settings-file`     | `string`  | Empty                     | Path to repository-owned formatter settings                                                  |
| `severity`                 | `string`  | `Error,Warning`           | Comma-separated lint diagnostic severities to report                                         |
| `lint-fail-on-findings`    | `boolean` | `true`                    | Fail the lint job when selected diagnostics exist                                            |
| `format-fail-on-findings`  | `boolean` | `true`                    | Fail the formatting job on differences in check mode                                         |
| `fix`                      | `boolean` | `false`                   | Apply formatting in the formatting job and upload a patch                                    |
| `psscriptanalyzer-version` | `string`  | `1.24.0`                  | PSScriptAnalyzer version used by both jobs                                                   |
| `runner-image`             | `string`  | `ubuntu-latest`           | Runner image used by both jobs, with `pwsh` available                                        |
| `templates-ref`            | `string`  | `main`                    | PipelineTemplates branch, tag, or commit SHA containing shared scripts and fallback settings |
| `artifact-name`            | `string`  | `powershell-format-patch` | Formatting patch artifact name                                                               |
| `artifact-retention-days`  | `number`  | `7`                       | Number of days to retain the formatting patch                                                |

## Configuration

Lint and formatter settings are resolved independently:

| Operation | Explicit input         | Automatically discovered local file | Central fallback                                  |
| --------- | ---------------------- | ----------------------------------- | ------------------------------------------------- |
| Lint      | `lint-settings-file`   | `PSScriptAnalyzerSettings.psd1`     | `config/powershell/PSScriptAnalyzerSettings.psd1` |
| Format    | `format-settings-file` | `FormatterSettings.psd1`            | `config/powershell/FormatterSettings.psd1`        |

Automatically discovered files must be in the calling repository's main folder. Explicit paths start from that folder and must remain inside the repository. An explicitly requested file must exist. The selected local file replaces the central configuration for that operation; settings are not merged.

For example:

```yaml
with:
  lint-settings-file: config/powershell/PSScriptAnalyzerSettings.psd1
  format-settings-file: config/powershell/FormatterSettings.psd1
```

A repository can customize only one operation and retain the fallback behavior for the other:

```yaml
with:
  lint-settings-file: PSScriptAnalyzerSettings.psd1
  format-settings-file: ""
```

See the individual workflow documentation for configuration details:

- [Lint configuration](../powershell-lint/README.md#configuration).
- [Formatter configuration](../powershell-format/README.md#configuration).

## File selection

Both jobs receive the same `paths` and `exclude-paths` values.

Use `.` to check all tracked PowerShell files:

```yaml
with:
  paths: "."
```

Select particular folders or files, one per line:

```yaml
with:
  paths: |
    modules
    scripts
    Microsoft.PowerShell_profile.ps1
```

Skip files using PowerShell wildcard patterns against paths starting from the repository's main folder:

```yaml
with:
  exclude-paths: |
    vendor/*
    tests/fixtures/*
```

Only tracked `.ps1`, `.psm1`, and `.psd1` files are selected. Untracked files are not checked, and there are no default dependency-folder exclusions. If no files match, each job reports that fact and succeeds.

## Linting and formatting jobs

The coordinator calls:

```text
validate-powershell
├── powershell-lint
└── powershell-format
```

Neither job depends on the other. Lint findings do not prevent formatting diagnostics from being collected. Each job has a separate checkout. When `fix: true`, formatting changes do not appear in the lint job's checkout during the same run. The coordinator references the individual reusable workflows using relative paths, selecting their workflow definitions from the same commit as the coordinator.

The `templates-ref` input separately controls the checkout containing the shared scripts and fallback settings. Keep it aligned with the coordinator's workflow reference while testing a feature branch.

## Reports and policy

The individual jobs produce their own logs, annotations, and summaries. The coordinator does not combine these into a separate aggregate report.

| Setting                          | Behavior                                                                                                         |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `lint-fail-on-findings: true`    | Lint findings fail the lint job                                                                                  |
| `lint-fail-on-findings: false`   | Lint findings are reported without failing the lint job                                                          |
| `format-fail-on-findings: true`  | Formatting differences fail the formatting job in check mode                                                     |
| `format-fail-on-findings: false` | Formatting differences are reported without failing the formatting job                                           |
| `fix: true`                      | Formatting changes are applied in the formatting job; successful fixes do not fail for the corrected differences |

Execution failures remain blocking regardless of these settings. When fix mode produces changes, the formatting job uploads a patch. The workflow does not commit, push, or automatically update a pull request.

Provide a unique `artifact-name` when multiple validation calls can produce formatting patches in the same run.

## Permissions

Both operations require only read access:

```yaml
permissions:
  contents: read
```

No write permission is required, including when `fix: true`.

## Examples

### Validate pull requests to main

This caller runs when a pull request targeting `main` is opened, updated with commits, reopened, or edited, provided its changed files include a selected PowerShell extension.

```yaml
---
name: Validate PowerShell

on:
  pull_request:
    types:
      - opened
      - synchronize
      - reopened
      - edited
    branches:
      - main
    paths:
      - "**/*.ps1"
      - "**/*.psm1"
      - "**/*.psd1"

permissions:
  contents: read

jobs:
  validate:
    uses: redjax/PipelineTemplates/.github/workflows/validate-powershell.yml@feat/powershell-lint
    with:
      templates-ref: feat/powershell-lint
      lint-fail-on-findings: true
      format-fail-on-findings: true
      fix: false
```

The trigger's `paths` filter controls whether the workflow starts. Once started, the default `paths: "."` input checks all tracked PowerShell files, not only the changed files.

### Use repository settings

```yaml
jobs:
  validate:
    uses: redjax/PipelineTemplates/.github/workflows/validate-powershell.yml@feat/powershell-lint
    with:
      templates-ref: feat/powershell-lint
      lint-settings-file: PSScriptAnalyzerSettings.psd1
      format-settings-file: FormatterSettings.psd1
```

### Non-blocking baseline validation

```yaml
jobs:
  validate:
    uses: redjax/PipelineTemplates/.github/workflows/validate-powershell.yml@feat/powershell-lint
    with:
      templates-ref: feat/powershell-lint
      lint-fail-on-findings: false
      format-fail-on-findings: false
      fix: false
```

Review the logs and annotations, remediate findings or document intentional exceptions, then enable enforcement for each operation.

### Scan selected folders

```yaml
jobs:
  validate:
    uses: redjax/PipelineTemplates/.github/workflows/validate-powershell.yml@feat/powershell-lint
    with:
      templates-ref: feat/powershell-lint
      paths: |
        modules
        scripts
      exclude-paths: |
        modules/vendor/*
        scripts/tests/fixtures/*
```

### Manual validation with optional formatting fixes

```yaml
---
name: Validate PowerShell manually

on:
  workflow_dispatch:
    inputs:
      fix:
        description: Fix formatting and upload a patch; does not commit or push.
        required: false
        type: boolean
        default: false

      lint-fail-on-findings:
        description: Fail when lint findings exist.
        required: false
        type: boolean
        default: false

      format-fail-on-findings:
        description: Fail on formatting differences in check mode.
        required: false
        type: boolean
        default: false

permissions:
  contents: read

jobs:
  validate:
    uses: redjax/PipelineTemplates/.github/workflows/validate-powershell.yml@feat/powershell-lint
    with:
      templates-ref: feat/powershell-lint
      fix: ${{ inputs.fix == true }}
      lint-fail-on-findings: ${{ inputs['lint-fail-on-findings'] == true }}
      format-fail-on-findings: ${{ inputs['format-fail-on-findings'] == true }}
      artifact-name: powershell-validation-format-patch
      artifact-retention-days: 7
```

Download and review any formatting patch using the procedure in the [formatter documentation](../powershell-format/README.md#apply-a-formatting-patch).
