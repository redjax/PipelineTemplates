# Gitleaks Secret Scan <!-- omit in toc -->

The [`gitleaks-secret-scan` workflow](../../../../../.github/workflows/gitleaks-secret-scan.yml) scans a consuming repository for hard-coded credentials, private keys, access tokens, and other secret-like content using [gitleaks](https://gitleaks.io/).

The workflow downloads and runs a requested Gitleaks version, uploads SARIF findings to GitHub Code Scanning, and uploads JSON or optional CSV reports as workflow artifacts.

The consuming repository controls workflow triggers, schedules, repository-specific Gitleaks configuration, baselines, report retention, and whether findings fail the workflow.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Configuration](#configuration)
- [Example use](#example-use)

## Responsibilities

- Check-out the consuming repository with complete Git history.
- Download and install the requested Gitleaks release.
- Run Gitleaks in Git-history or directory scanning mode.
- Generate SARIF and JSON reports.
- Optionally generate a CSV report.
- Upload SARIF findings to GitHub Code Scanning.
- Upload scan reports as a workflow artifact.
- Optionally fail when potential secrets are found.

## Inputs

- `gitleaks-version`: Gitleaks version to download, without a leading `v`.
- `mode`: Scan mode: `git` scans Git history; `dir` scans a file or directory path.
- `source`: Source directory or file path when `mode` is `dir`.
- `config-path`: Optional path to a repository-local Gitleaks configuration file.
- `baseline-path`: Optional path to a repository-local Gitleaks baseline report.
- `fail-on-findings`: Whether the workflow fails when Gitleaks reports findings.
- `generate-csv-report`: Whether to generate a CSV report in addition to SARIF and JSON.
- `artifact-retention-days`: Number of days to retain scan artifacts.

## Configuration

Repository-specific false-positive handling should remain in the consuming repository.

A consuming repository can add `.gitleaks.toml` at its root to extend default Gitleaks rules and allowlist intentional example or fixture content:

```toml
[extend]
useDefault = true

[allowlist]
description = "Intentional fake private-key fixture"

paths = [
  '''^\.concourse/examples/go-app/example\.go-app\.secrets\.yml$''',
]
```

Pass the configuration file explicitly when desired:

```yaml
config-path: ".gitleaks.toml"
```

A baseline can be used to report existing known findings without failing for them, while still detecting newly introduced findings:

```yaml
baseline-path: ".gitleaks-baseline.json"
```

## Example use

This is a normal full-history scan with default Gitleaks configuration:

```yaml
---
name: Secrets Scan

on:
  pull_request:
  push:
    branches:
      - main
  schedule:
    ## Every day at 03:00 UTC.
    - cron: "0 3 * * *"
  workflow_dispatch:

permissions:
  actions: read
  contents: read
  security-events: write

jobs:
  gitleaks:
    uses: redjax/PipelineTemplates/.github/workflows/gitleaks-secret-scan.yml@main
    with:
      gitleaks-version: "8.30.1"
      mode: git
      fail-on-findings: true
      generate-csv-report: false
      artifact-retention-days: 30
```

This example uses a repository-local Gitleaks configuration and a baseline:

```yaml
---
jobs:
  gitleaks:
    uses: redjax/PipelineTemplates/.github/workflows/gitleaks-secret-scan.yml@main
    with:
      gitleaks-version: "8.30.1"
      mode: git
      config-path: ".gitleaks.toml"
      baseline-path: ".gitleaks-baseline.json"
      fail-on-findings: true
      generate-csv-report: true
      artifact-retention-days: 30
```

To scan only the checked-out working tree rather than complete Git history:

```yaml
---
jobs:
  gitleaks:
    uses: redjax/PipelineTemplates/.github/workflows/gitleaks-secret-scan.yml@main
    with:
      gitleaks-version: "8.30.1"
      mode: dir
      source: "."
      fail-on-findings: true
```
