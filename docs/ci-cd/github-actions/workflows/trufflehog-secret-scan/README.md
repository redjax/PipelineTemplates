# TruffleHog Secret Scan <!-- omit in toc -->

The [`trufflehog-secret-scan` workflow](../../../../../.github/workflows/trufflehog-secret-scan.yml) runs [TruffleHog](https://github.com/trufflesecurity/trufflehog) against a consuming repository to identify potentially exposed credentials, tokens, private keys, and other supported secret types.

The workflow installs a requested TruffleHog release, scans either complete Git history or the checked-out filesystem, and uploads JSON findings as a workflow artifact.

By default, TruffleHog uses its built-in detectors and reports verified findings only. A consuming repository can optionally provide a custom TruffleHog configuration file when it needs custom detectors or repository-specific behavior.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Scan modes](#scan-modes)
- [Result types](#result-types)
- [Configuration](#configuration)
- [Artifacts](#artifacts)
- [Example use](#example-use)

## Responsibilities

- Check-out the consuming repository.
- Fetch complete Git history for Git-based scans.
- Download and install the requested TruffleHog release.
- Run TruffleHog against Git history or a filesystem path.
- Use TruffleHog built-in detectors when no custom configuration is provided.
- Produce JSON output when TruffleHog reports findings.
- Upload JSON findings as a workflow artifact.
- Optionally fail when TruffleHog reports findings.

## Inputs

- `trufflehog-version`: TruffleHog release version to install, without a leading `v`.
- `mode`: Scan mode: `git` scans Git history; `filesystem` scans current files only.
- `source`: Source path or repository URL to scan.
- `config-path`: Optional repository-local TruffleHog configuration file.
- `results`: Finding categories to report, i.e. `verified`, `unknown`, `invalid`, or a comma-separated combination.
- `fail-on-findings`: Whether the workflow fails when TruffleHog reports findings in the requested result categories.
- `artifact-retention-days`: Number of days to retain TruffleHog JSON result artifacts.

## Scan modes

Use `git` mode for normal scheduled security scans:

```yaml
mode: git
```

Git mode scans the consuming repository's complete Git history. This is useful for detecting credentials that may have been removed from current files but still exist in prior commits.

Use `filesystem` mode when scanning only the currently checked-out source tree:

```yaml
mode: filesystem
source: "."
```

Filesystem mode does not scan previous commits.

## Result types

The default result type is:

```yaml
results: "verified"
```

Verified findings are credentials that TruffleHog was able to validate against a relevant provider or service.

This is the recommended default for scheduled scans because verified credentials are high-confidence findings and should normally be rotated, revoked, or otherwise remediated immediately.

To include findings that TruffleHog could not verify, use:

```yaml
results: "verified,unknown"
```

This provides broader coverage but may produce more findings requiring manual review.

> [!WARNING]
> Use `unknown` carefully. A credential may be unverified because it is invalid, expired, inaccessible from the GitHub Actions runner, or associated with a provider that cannot be verified automatically.

## Configuration

TruffleHog includes built-in detectors and does not require a configuration file for normal scans.

Leave `config-path` empty to use the built-in detector set:

```yaml
# config-path: ""
```

Provide `config-path` only when the consuming repository needs custom TruffleHog behavior or custom detectors:

```yaml
config-path: ".trufflehog.yaml"
```

The configuration file belongs in the consuming repository. This keeps repository-specific secret patterns, detector configuration, and exclusions under review with the code that requires them.

## Artifacts

When TruffleHog finds results, the workflow uploads this artifact:

```text
trufflehog-scan-results
```

The artifact contains:

```text
trufflehog-results.json
```

When no findings exist for the configured `results` categories, TruffleHog produces no JSON result file and the workflow does not upload an artifact.

For example, a successful verified-only scan with no active credentials reports:

```text
verified_secrets: 0
unverified_secrets: 0
```

## Example use

This is the recommended full-history scan for a consuming repository:

```yaml
---
name: TruffleHog Secret Scan

on:
  pull_request:
  push:
    branches:
      - main
  schedule:
    ## Every Sunday at 02:00 UTC.
    - cron: "0 2 * * 0"
  workflow_dispatch:

permissions:
  actions: read
  contents: read

jobs:
  trufflehog:
    uses: redjax/PipelineTemplates/.github/workflows/trufflehog-secret-scan.yml@main
    with:
      trufflehog-version: "3.96.0"
      mode: git
      source: "."
      results: "verified"
      fail-on-findings: true
      artifact-retention-days: 30
```

This performs a filesystem-only scan:

```yaml
---
jobs:
  trufflehog:
    uses: redjax/PipelineTemplates/.github/workflows/trufflehog-secret-scan.yml@main
    with:
      trufflehog-version: "3.96.0"
      mode: filesystem
      source: "."
      results: "verified"
      fail-on-findings: true
```

This uses a repository-local custom TruffleHog configuration and includes unverified findings for manual review:

```yaml
---
jobs:
  trufflehog:
    uses: redjax/PipelineTemplates/.github/workflows/trufflehog-secret-scan.yml@main
    with:
      trufflehog-version: "3.96.0"
      mode: git
      source: "."
      config-path: ".trufflehog.yaml"
      results: "verified,unknown"
      fail-on-findings: true
      artifact-retention-days: 30
```

This reports findings but does not fail the workflow:

```yaml
---
jobs:
  trufflehog:
    uses: redjax/PipelineTemplates/.github/workflows/trufflehog-secret-scan.yml@main
    with:
      trufflehog-version: "3.96.0"
      mode: git
      source: "."
      results: "verified,unknown"
      fail-on-findings: false
```
