# Security Scans <!-- omit in toc -->

The [`security-scans` reusable workflow](../../../../../.github/workflows/security-scans.yml) orchestrates the centrally managed security-scanning workflows in `PipelineTemplates`.

A consuming repository calls this workflow once and enables the scanners it wants to run. The orchestrator creates one independent job for each enabled scanner and forwards scanner-specific inputs to that scanner's workflow.

## Table of Contents <!-- omit in toc -->

- [Default behavior](#default-behavior)
- [Scanners](#scanners)
- [Inputs](#inputs)
  - [Scanner selection](#scanner-selection)
  - [Scanner configuration](#scanner-configuration)
    - [Trivy](#trivy)
    - [Gitleaks](#gitleaks)
    - [OSV-Scanner](#osv-scanner)
    - [CodeQL](#codeql)
    - [TruffleHog](#trufflehog)
  - [Shared inputs](#shared-inputs)
- [Calling the workflow](#calling-the-workflow)
- [Scheduled scans](#scheduled-scans)
- [Feature branches](#feature-branches)

## Default behavior

All scanners are disabled by default. The consuming repository controls scanner selection with the following inputs:

```yaml
with:
  enableTrivy: true
  enableGitleaks: false
  enableOSV: true
  enableCodeQL: false
  enableTruffleHog: true
```

Only enabled scanners are created and executed. Scanner reports, artifacts, SARIF uploads, and failure behavior are handled by the individual scanner workflows. If a scanner does not run, no report will be uploaded.

## Scanners

Individual scanner behavior is documented separately:

| Available Scanners                                     |
| ------------------------------------------------------ |
| [`trivy-scan`](../trivy-scan/)                         |
| [`gitleaks-secret-scan`](../gitleaks-secret-scan/)     |
| [`osv-scan`](../osv-scan/)                             |
| [`codeql-analysis`](../codeql-analysis/)               |
| [`trufflehog-secret-scan`](../trufflehog-secret-scan/) |

## Inputs

### Scanner selection

| Input              | Type      | Default | Description      |
| ------------------ | --------- | ------: | ---------------- |
| `enableTrivy`      | `boolean` | `false` | Run Trivy.       |
| `enableGitleaks`   | `boolean` | `false` | Run Gitleaks.    |
| `enableOSV`        | `boolean` | `false` | Run OSV-Scanner. |
| `enableCodeQL`     | `boolean` | `false` | Run CodeQL.      |
| `enableTruffleHog` | `boolean` | `false` | Run TruffleHog.  |

### Scanner configuration

The orchestrator forwards scanner-specific inputs to the corresponding reusable workflow. For detailed descriptions, defaults, and examples, see the documentation page for each scanner.

#### Trivy

The orchestrator forwards these inputs to [`trivy-scan`](../trivy-scan/):

- `trivyVersion`
- `trivyScanType`
- `trivyScanPath`
- `trivyImageRef`
- `trivyScanners`
- `trivySeverity`
- `trivyIgnoreUnfixed`
- `trivyConfigPath`
- `trivyIgnoreFile`
- `trivySkipDirs`
- `failOnTrivyFindings`

#### Gitleaks

The orchestrator forwards these inputs to [`gitleaks-secret-scan`](../gitleaks-secret-scan/):

- `gitleaksVersion`
- `gitleaksMode`
- `gitleaksSource`
- `gitleaksConfigPath`
- `gitleaksBaselinePath`
- `failOnGitleaksFindings`
- `gitleaksGenerateCsvReport`

#### OSV-Scanner

The orchestrator forwards these inputs to [`osv-scan`](../osv-scan/):

- `osvScannerVersion`
- `osvSource`
- `osvRecursive`
- `osvConfigPath`
- `osvNoResolve`
- `osvAllowNoPackageSources`
- `osvVerbosity`
- `osvAdditionalArgs`
- `failOnOSVFindings`
- `osvSarifCategory`

#### CodeQL

The orchestrator forwards these inputs to [`codeql-analysis`](../codeql-analysis/):

- `codeqlLanguages`
- `codeqlQueries`
- `codeqlRunBuild`
- `codeqlBuildCommands`
- `codeqlUploadSarif`
- `codeqlFailOnError`
- `codeqlCategory`

#### TruffleHog

The orchestrator forwards these inputs to [`trufflehog-secret-scan`](../trufflehog-secret-scan/):

- `trufflehogVersion`
- `trufflehogMode`
- `trufflehogSource`
- `trufflehogConfigPath`
- `trufflehogResults`
- `failOnTruffleHogFindings`

### Shared inputs

| Input                   | Type     | Default | Description                                                                                                 |
| ----------------------- | -------- | ------: | ----------------------------------------------------------------------------------------------------------- |
| `artifactRetentionDays` | `number` |    `30` | Artifact retention period passed to enabled scanners.                                                       |
| `pipelineTemplatesRef`  | `string` |  `main` | Branch, tag, or commit used by nested scanner workflows when checking out shared PipelineTemplates scripts. |

## Calling the workflow

A consuming repository calls the orchestrator as a job:

```yaml
---
name: Security scans

on:
  workflow_dispatch:

permissions:
  actions: read
  contents: read
  security-events: write

jobs:
  security-scans:
    name: Run security scans
    permissions:
      actions: read
      contents: read
      security-events: write
    uses: redjax/PipelineTemplates/.github/workflows/security-scans.yml@main
    with:
      enableTrivy: true
      enableGitleaks: false
      enableOSV: true
      enableCodeQL: false
      enableTruffleHog: true

      trivyIgnoreFile: .trivyignore.yaml
      osvAllowNoPackageSources: true

      failOnTrivyFindings: true
      failOnOSVFindings: true
      failOnTruffleHogFindings: true
```

The consuming repository should enable only the scanners appropriate for its contents. For example, a repository containing Dockerfiles but no application dependency manifests may use:

```yaml
with:
  enableTrivy: true
  enableGitleaks: true
  enableOSV: true
  enableCodeQL: false
  enableTruffleHog: true
  osvAllowNoPackageSources: true
```

## Scheduled scans

Scheduled workflows do not receive `workflow_dispatch` input values. Select scheduled scanner behavior explicitly with `github.event_name`:

```yaml
---
name: Security scans

on:
  schedule:
    - cron: "0 0 * * 0"

  workflow_dispatch:
    inputs:
      enableTrivy:
        description: Run Trivy
        required: false
        type: boolean
        default: false

      enableOSV:
        description: Run OSV-Scanner
        required: false
        type: boolean
        default: false

      enableTruffleHog:
        description: Run TruffleHog
        required: false
        type: boolean
        default: false

permissions:
  actions: read
  contents: read
  security-events: write

jobs:
  security-scans:
    uses: redjax/PipelineTemplates/.github/workflows/security-scans.yml@main
    permissions:
      actions: read
      contents: read
      security-events: write
    with:
      enableTrivy: ${{ github.event_name == 'schedule' || inputs.enableTrivy }}
      enableGitleaks: false
      enableOSV: ${{ github.event_name == 'schedule' || inputs.enableOSV }}
      enableCodeQL: false
      enableTruffleHog: ${{ github.event_name == 'schedule' || inputs.enableTruffleHog }}

      trivyIgnoreFile: ${{ inputs.trivyIgnoreFile || '.trivyignore.yaml' }}
      osvAllowNoPackageSources: true

      failOnTrivyFindings: ${{ github.event_name == 'schedule' || inputs.failOnTrivyFindings }}
      failOnOSVFindings: ${{ github.event_name == 'schedule' || inputs.failOnOSVFindings }}
      failOnTruffleHogFindings: ${{ github.event_name == 'schedule' || inputs.failOnTruffleHogFindings }}
```

## Feature branches

When testing a feature branch, pin both the orchestrator and the shared-script reference to the same branch:

```yaml
jobs:
  security-scans:
    uses: redjax/PipelineTemplates/.github/workflows/security-scans.yml@feat/some-feature-branch
    with:
      enableTrivy: true
      enableOSV: true
      enableTruffleHog: true
      pipelineTemplatesRef: feat/some-feature-branch
```

The workflow reference selects the orchestrator workflow. `pipelineTemplatesRef` selects the PipelineTemplates revision used by nested scanner workflows for shared scripts.
