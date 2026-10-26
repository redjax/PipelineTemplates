# PowerShell lint <!-- omit in toc -->

The [`powershell-lint` reusable workflow](../../../../../.github/workflows/powershell-lint.yml) runs [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) against PowerShell files in a calling repository.

The workflow checks scripts, modules, and module manifests for code-quality and correctness issues. It reports findings without executing the selected scripts or importing the selected modules.

The workflow uses the shared [`lint.ps1` script](../../../../../shared/scripts/ci-cd/powershell/lint.ps1) and supports consuming repository-owned settings or the [central lint configuration](../../../../../config/powershell/PSScriptAnalyzerSettings.psd1).

## Table of Contents <!-- omit in toc -->

- [Default behavior](#default-behavior)
- [Inputs](#inputs)
- [Configuration](#configuration)
  - [Central configuration](#central-configuration)
  - [Repository-owned configuration](#repository-owned-configuration)
  - [Rule exclusions](#rule-exclusions)
- [File selection](#file-selection)
- [Reports and policy](#reports-and-policy)
- [Permissions](#permissions)
- [Examples](#examples)
  - [Minimal scan](#minimal-scan)
  - [Use repository settings](#use-repository-settings)
  - [Scan selected folders](#scan-selected-folders)
  - [Manual baseline scan](#manual-baseline-scan)

## Default behavior

With no caller-provided inputs, the workflow:

- Checks out the calling repository.
- Checks out `redjax/PipelineTemplates` at `templates-ref`.
- Installs PSScriptAnalyzer version.
- Selects tracked `.ps1`, `.psm1`, and `.psd1` files throughout the repository.
- Applies no additional path exclusions.
- Uses `PSScriptAnalyzerSettings.psd1` from the calling repository's main folder when present.
- Uses the central lint settings when no repository-local settings file exists.
- Reports findings with `Error` or `Warning` severity.
- Prints findings in the job log and emits GitHub annotations.
- Adds a summary containing file and finding counts.
- Fails when selected lint findings exist.
- Always fails when installation, configuration, or execution fails.

> [!NOTE]
> Linting does not rewrite files. Use the [`powershell-format`](../powershell-format/README.md) workflow to check or apply formatting.

## Inputs

| Input                      | Type      | Default         | Description                                                                                          |
| -------------------------- | --------- | --------------- | ---------------------------------------------------------------------------------------------------- |
| `paths`                    | `string`  | `.`             | Files or folders to check. Put each entry on its own line. Only tracked PowerShell files are checked |
| `exclude-paths`            | `string`  | Empty           | Files or folders to skip, one wildcard pattern per line                                              |
| `settings-file`            | `string`  | Empty           | Path to a lint settings file, starting from the calling repository's main folder                     |
| `severity`                 | `string`  | `Error,Warning` | Comma-separated diagnostic severities to report                                                      |
| `fail-on-findings`         | `boolean` | `true`          | Fail on findings; set to `false` to report warning annotations without failing                       |
| `psscriptanalyzer-version` | `string`  | `1.24.0`        | PSScriptAnalyzer version to install from PowerShell Gallery                                          |
| `runner-image`             | `string`  | `ubuntu-latest` | Runner image with `pwsh` available                                                                   |
| `templates-ref`            | `string`  | `main`          | PipelineTemplates branch, tag, or commit SHA containing shared scripts and fallback settings         |

## Configuration

The workflow selects settings in this order:

1. The file explicitly supplied through `settings-file`.
2. `PSScriptAnalyzerSettings.psd1` in the calling repository's main folder.
3. The central `config/powershell/PSScriptAnalyzerSettings.psd1` file.

The selected configuration replaces the other choices. Local and central settings are not merged, so if a consuming repository provides its own configuration, the pipeline uses that instead of the central one. An explicitly supplied settings file must exist; a missing file fails the run instead of silently selecting the central fallback.

### Central configuration

The central settings are stored in:

```text
config/powershell/PSScriptAnalyzerSettings.psd1
```

Leave `settings-file` empty to enable local-file discovery and central fallback:

```yaml
with:
  settings-file: ""
```

The central lint configuration reports warnings and errors. It excludes the formatting rules handled by the separate formatting workflow.

### Repository-owned configuration

Place a file named `PSScriptAnalyzerSettings.psd1` in the calling repository's main folder for automatic discovery.

Alternatively, explicitly select a settings file:

```yaml
with:
  settings-file: config/powershell/PSScriptAnalyzerSettings.psd1
```

Paths start from the calling repository's main folder. They must not point outside the repository. Match the actual filename's capitalization. For example, a lowercase filename can be selected explicitly:

```yaml
with:
  settings-file: psscriptanalyzersettings.psd1
```

### Rule exclusions

A repository can maintain its own rule exclusions:

```powershell
@{
    Severity = @(
        'Error'
        'Warning'
    )

    ExcludeRules = @(
        ## Formatting is checked separately.
        'PSPlaceOpenBrace'
        'PSPlaceCloseBrace'
        'PSUseConsistentWhitespace'
        'PSUseConsistentIndentation'
        'PSAlignAssignmentStatement'
        'PSUseCorrectCasing'
    )
}
```

Add repository-specific exceptions to the local settings rather than weakening the central defaults for every caller. The workflow's `severity` input also selects reported diagnostic severities. Keep it consistent with the intended policy in your settings file.

## File selection

The workflow checks tracked files with these extensions:

```text
.ps1
.psm1
.psd1
```

Use `.` to check the entire repository:

```yaml
with:
  paths: "."
```

Select specific folders or files by placing each on its own line:

```yaml
with:
  paths: |
    scripts
    modules
    Microsoft.PowerShell_profile.ps1
```

The entries are passed to `git ls-files`. Untracked files are not checked. Exclude files using wildcard patterns against paths starting from the repository's main folder:

```yaml
with:
  exclude-paths: |
    vendor/*
    tests/fixtures/*
```

Exclusions use PowerShell wildcard matching, not `.gitignore` syntax. For example, `vendor/*` skips tracked files beneath `vendor`. There are no default dependency or generated-folder exclusions. Tracked PowerShell files remain eligible unless explicitly excluded. The separate PipelineTemplates checkout is not scanned. If no matching files are found, the workflow reports that fact and succeeds.

## Reports and policy

Each finding includes:

- File path.
- Line and column.
- Rule name.
- Diagnostic severity.
- Message.

Findings appear in the job log and GitHub annotations. A job summary records the selected settings file, file count, and finding count.

The lint workflow does not upload a separate report artifact.

| Outcome                                           | Script exit code                                         | Workflow behavior                                    |
| ------------------------------------------------- | -------------------------------------------------------- | ---------------------------------------------------- |
| No findings                                       | `0`                                                      | Succeeds                                             |
| Findings with `fail-on-findings: true`            | `1`                                                      | Reports findings and fails                           |
| Findings with `fail-on-findings: false`           | `0`                                                      | Reports findings as warning annotations and succeeds |
| Installation, configuration, or execution failure | Script failures use `2`; installation fails its own step | Fails regardless of `fail-on-findings`               |

Use warning-only mode while establishing a baseline:

```yaml
with:
  fail-on-findings: false
```

Review the findings, fix issues or document intentional exceptions, then enable enforcement.

## Permissions

The workflow only needs read access:

```yaml
permissions:
  contents: read
```

It does not commit, push, or execute the selected profile scripts.

## Examples

### Minimal scan

```yaml
---
name: PowerShell lint

on:
  pull_request:
    branches:
      - main
    paths:
      - "**/*.ps1"
      - "**/*.psm1"
      - "**/*.psd1"

permissions:
  contents: read

jobs:
  lint:
    uses: redjax/PipelineTemplates/.github/workflows/powershell-lint.yml@feat/powershell-lint
    with:
      templates-ref: feat/powershell-lint
```

### Use repository settings

```yaml
jobs:
  lint:
    uses: redjax/PipelineTemplates/.github/workflows/powershell-lint.yml@feat/powershell-lint
    with:
      templates-ref: feat/powershell-lint
      settings-file: PSScriptAnalyzerSettings.psd1
      fail-on-findings: true
```

### Scan selected folders

```yaml
jobs:
  lint:
    uses: redjax/PipelineTemplates/.github/workflows/powershell-lint.yml@feat/powershell-lint
    with:
      templates-ref: feat/powershell-lint
      paths: |
        scripts
        modules
      exclude-paths: |
        modules/vendor/*
        scripts/tests/fixtures/*
```

### Manual baseline scan

```yaml
---
name: Lint PowerShell

on:
  workflow_dispatch:
    inputs:
      fail-on-findings:
        description: Fail the run when lint issues are found.
        required: false
        type: boolean
        default: false

permissions:
  contents: read

jobs:
  lint:
    uses: redjax/PipelineTemplates/.github/workflows/powershell-lint.yml@feat/powershell-lint
    with:
      templates-ref: feat/powershell-lint
      paths: "."
      fail-on-findings: ${{ inputs['fail-on-findings'] == true }}
```

Keep the workflow reference and `templates-ref` aligned while testing a feature branch.
