# PowerShell format <!-- omit in toc -->

The [`powershell-format` reusable workflow](../../../../../.github/workflows/powershell-format.yml) checks or applies formatting to PowerShell files in a calling repository.

The workflow uses [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer)'s `Invoke-Formatter` command through the shared [`format.ps1` script](../../../../../shared/scripts/ci-cd/powershell/format.ps1).

Formatting settings come from a repository-owned file or the [central formatter configuration](../../../../../config/powershell/FormatterSettings.psd1), although consuming repossitories can provide their own using the `settings-file` input.

## Table of Contents <!-- omit in toc -->

- [Default behavior](#default-behavior)
- [Inputs](#inputs)
- [Configuration](#configuration)
  - [Central configuration](#central-configuration)
  - [Repository-owned configuration](#repository-owned-configuration)
- [File selection](#file-selection)
- [Check and fix modes](#check-and-fix-modes)
  - [Check mode](#check-mode)
  - [Fix mode](#fix-mode)
  - [Encoding and line endings](#encoding-and-line-endings)
- [Reports and policy](#reports-and-policy)
- [Permissions](#permissions)
- [Examples](#examples)
  - [Minimal formatting check](#minimal-formatting-check)
  - [Use repository settings](#use-repository-settings)
  - [Manual check or fix](#manual-check-or-fix)
  - [Apply a formatting patch](#apply-a-formatting-patch)

## Default behavior

With no caller-provided inputs, the workflow:

- Checks out the calling repository.
- Checks out `redjax/PipelineTemplates` at `templates-ref`.
- Installs PSScriptAnalyzer.
- Selects tracked `.ps1`, `.psm1`, and `.psd1` files throughout the repository.
- Applies no additional path exclusions.
- Uses `FormatterSettings.psd1` from the calling repository's main folder when present.
- Uses the central formatter settings when no repository-local settings file exists.
- Checks formatting without modifying source files.
- Prints formatting differences in the job log.
- Emits GitHub annotations and adds a job summary.
- Fails when formatting differences exist.
- Always fails when installation, configuration, parsing, or execution fails.

> [!NOTE]
> Formatting does not replace linting. Use [`powershell-lint`](../powershell-lint/README.md) for static analysis or [`validate-powershell`](../validate-powershell/README.md) to run both operations.

## Inputs

| Input                      | Type      | Default                   | Description                                                                                          |
| -------------------------- | --------- | ------------------------- | ---------------------------------------------------------------------------------------------------- |
| `paths`                    | `string`  | `.`                       | Files or folders to check. Put each entry on its own line. Only tracked PowerShell files are checked |
| `exclude-paths`            | `string`  | Empty                     | Files or folders to skip, one wildcard pattern per line                                              |
| `settings-file`            | `string`  | Empty                     | Path to a formatter settings file, starting from the calling repository's main folder                |
| `fix`                      | `boolean` | `false`                   | Write formatted files in the runner workspace and upload a patch                                     |
| `fail-on-findings`         | `boolean` | `true`                    | Fail on formatting differences in check mode                                                         |
| `psscriptanalyzer-version` | `string`  | `1.24.0`                  | PSScriptAnalyzer version to install from PowerShell Gallery                                          |
| `runner-image`             | `string`  | `ubuntu-latest`           | Runner image with `pwsh` available                                                                   |
| `templates-ref`            | `string`  | `main`                    | PipelineTemplates branch, tag, or commit SHA containing shared scripts and fallback settings         |
| `artifact-name`            | `string`  | `powershell-format-patch` | Name of the uploaded formatting patch artifact                                                       |
| `artifact-retention-days`  | `number`  | `7`                       | Number of days to retain the patch artifact                                                          |

## Configuration

The workflow selects settings in this order:

1. The file explicitly supplied through `settings-file`.
2. `FormatterSettings.psd1` in the calling repository's main folder.
3. The central `config/powershell/FormatterSettings.psd1` file.

Settings are selected, not merged, meaning if a repository provides its own configuration, the central one is not used. An explicitly requested settings file must exist. A missing file fails the run instead of silently selecting the central fallback.

### Central configuration

The central formatter settings are stored in:

```text
config/powershell/FormatterSettings.psd1
```

The fallback configures:

- Four-space indentation.
- Same-line opening braces.
- Consistent closing-brace placement.
- Consistent whitespace.
- Aligned hashtable assignments.

Leave `settings-file` empty to enable local-file discovery and central fallback:

```yaml
with:
  settings-file: ""
```

### Repository-owned configuration

Place `FormatterSettings.psd1` in the calling repository's main folder for automatic discovery.

Alternatively, explicitly select another location:

```yaml
with:
  settings-file: config/powershell/FormatterSettings.psd1
```

The path starts from the calling repository's main folder and must remain inside the repository.

Match the filename's capitalization.

Lint settings and formatter settings are independent. A local `PSScriptAnalyzerSettings.psd1` does not automatically become the formatter configuration.

## File selection

The workflow checks tracked files with these extensions:

```text
.ps1
.psm1
.psd1
```

Check the entire repository:

```yaml
with:
  paths: "."
```

Select files or folders, one per line:

```yaml
with:
  paths: |
    scripts
    modules
    Microsoft.PowerShell_profile.ps1
```

The entries are passed to `git ls-files`. Untracked files are not checked.

Skip files using PowerShell wildcard patterns against paths starting from the repository's main folder:

```yaml
with:
  exclude-paths: |
    vendor/*
    tests/fixtures/*
```

There are no default dependency or generated-folder exclusions.

The separate PipelineTemplates checkout is not scanned. If no matching files exist, the workflow reports that fact and succeeds.

## Check and fix modes

### Check mode

Check mode is the default:

```yaml
with:
  fix: false
```

The script:

1. Reads each selected file.
2. Checks that its PowerShell syntax can be parsed.
3. Formats its contents in memory.
4. Compares the original and formatted text.
5. Prints a diff when they differ.

Source files are not modified.

Set `fail-on-findings: false` to display differences without failing the run:

```yaml
with:
  fix: false
  fail-on-findings: false
```

### Fix mode

Enable fix mode:

```yaml
with:
  fix: true
```

The script:

1. Detects and displays formatting differences.
2. Checks the formatted output for syntax errors.
3. Verifies that a second formatting pass produces the same text.
4. Writes the formatted file into the runner workspace.
5. Generates a patch containing changes to the files it formatted.

Successfully corrected differences do not fail the run, even when `fail-on-findings` is enabled.

> [!IMPORTANT]
> Fix mode does not commit, push, or update a pull request. The workflow uploads a patch so the changes can be reviewed and applied locally.

If formatting fails partway through, files already processed may have changed in the runner workspace. Patch generation happens after file processing completes, so a failed run may not produce a patch.

### Encoding and line endings

The script detects byte order marks and preserves the detected encoding when writing fixes.

Files without a byte order mark are treated as UTF-8. Invalid UTF-8 input is rejected rather than silently replacing characters. Convert legacy ANSI-encoded files before formatting them.

Formatted text uses CRLF when the original file contains CRLF line endings; otherwise it uses LF. Files with mixed line endings are normalized by this choice.

## Reports and policy

Formatting differences appear as diffs in the job log. The workflow also emits annotations and records file counts, settings, and mode in the job summary.

| Outcome                                             | Script exit code        | Workflow behavior                                          |
| --------------------------------------------------- | ----------------------- | ---------------------------------------------------------- |
| No formatting differences                           | `0`                     | Succeeds                                                   |
| Differences in check mode with enforcement enabled  | `1`                     | Shows differences and fails                                |
| Differences in check mode with enforcement disabled | `0`                     | Shows differences, emits warning annotations, and succeeds |
| Differences successfully corrected in fix mode      | `0`                     | Shows differences, writes fixes, and uploads a patch       |
| Parsing, configuration, or execution failure        | `2`                     | Fails regardless of `fail-on-findings`                     |
| Installation failure                                | Installation step fails | Fails regardless of `fail-on-findings`                     |

Fix mode uploads `format.patch` under the artifact name selected by `artifact-name`. No patch artifact is created when there are no changes.

Check mode does not upload a separate diff artifact; review its job log.

Provide a unique artifact name when calling the formatter multiple times in the same workflow run:

```yaml
with:
  artifact-name: module-a-powershell-format-patch
```

## Permissions

The workflow requires only read access:

```yaml
permissions:
  contents: read
```

Fix mode does not require write access because changes remain in the runner workspace and are distributed as a patch artifact.

## Examples

### Minimal formatting check

```yaml
---
name: PowerShell formatting

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
  format:
    uses: redjax/PipelineTemplates/.github/workflows/powershell-format.yml@feat/powershell-lint
    with:
      templates-ref: feat/powershell-lint
```

### Use repository settings

```yaml
jobs:
  format:
    uses: redjax/PipelineTemplates/.github/workflows/powershell-format.yml@feat/powershell-lint
    with:
      templates-ref: feat/powershell-lint
      settings-file: config/powershell/FormatterSettings.psd1
      fix: false
      fail-on-findings: true
```

### Manual check or fix

```yaml
---
name: Format PowerShell

on:
  workflow_dispatch:
    inputs:
      fix:
        description: Fix formatting and upload a patch; does not commit or push.
        required: false
        type: boolean
        default: false

      fail-on-findings:
        description: Fail when formatting differences are found in check mode.
        required: false
        type: boolean
        default: false

permissions:
  contents: read

jobs:
  format:
    uses: redjax/PipelineTemplates/.github/workflows/powershell-format.yml@feat/powershell-lint
    with:
      templates-ref: feat/powershell-lint
      paths: "."
      fix: ${{ inputs.fix == true }}
      fail-on-findings: ${{ inputs['fail-on-findings'] == true }}
      artifact-name: powershell-format-patch
      artifact-retention-days: 7
```

### Apply a formatting patch

Download and extract the patch artifact from the completed workflow run.

From a local checkout matching the revision used by the run, check whether the patch applies:

```powershell
git apply --check /path/to/format.patch
```

Apply it and review the changes:

```powershell
git apply /path/to/format.patch
git diff
```

Commit and push the reviewed changes using the repository's normal contribution process.
