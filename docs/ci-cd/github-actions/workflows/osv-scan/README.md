# OSV Scan <!-- omit in toc -->

The [`osv-scan` workflow](../../../../../.github/workflows/osv-scan.yml) runs [OSV-Scanner](https://github.com/google/osv-scanner) against a consuming repository to identify known vulnerabilities affecting supported dependency manifests, lockfiles, and other recognized package metadata.

The workflow installs a requested OSV-Scanner release, retrieves the shared `osv-scan.sh` script from `PipelineTemplates`, produces a SARIF report, uploads findings to GitHub Code Scanning, and uploads the SARIF report as a workflow artifact.

The consuming repository controls scan scope, OSV-Scanner configuration, dependency-resolution behavior, additional scanner arguments, report retention, and vulnerability failure policy.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [When to use this workflow](#when-to-use-this-workflow)
- [Inputs](#inputs)
- [Additional arguments](#additional-arguments)
- [No package sources](#no-package-sources)
- [Example use](#example-use)

## Responsibilities

- Check-out the consuming repository.
- Check out the shared `osv-scan.sh` script from `PipelineTemplates`.
- Download and install the requested OSV-Scanner release.
- Run OSV-Scanner against the requested source path.
- Generate a SARIF report.
- Upload SARIF findings to GitHub Code Scanning.
- Upload the SARIF report as a workflow artifact.
- Optionally fail when OSV-Scanner reports known vulnerabilities.

## When to use this workflow

Use this workflow for repositories containing dependency metadata that OSV-Scanner can recognize, including package manifests, lockfiles, or SBOM files.

Typical examples include:

- Go repositories containing `go.mod` and `go.sum`.
- Node.js repositories containing `package-lock.json`, `npm-shrinkwrap.json`, or other supported package metadata.
- Python repositories containing supported requirements or lock files.
- Java repositories containing Maven or Gradle dependency metadata.
- Repositories containing a supported SBOM.

Do not normally use this workflow for repositories containing only pipeline YAML, documentation, shell scripts, templates, and examples without dependency metadata.

A repository without recognized package sources causes OSV-Scanner to report:

```text
No package sources found
```

By default, this is treated as a scan failure. Set `allow-no-package-sources` only when that outcome is intentional.

## Inputs

- `osv-scanner-version`: OSV-Scanner CLI release version to install, without a leading `v`.
- `source`: Source path to scan, relative to the consuming repository root.
- `recursive`: Whether to recursively search the source path for supported dependency files.
- `config-path`: Optional OSV-Scanner configuration file path.
- `no-resolve`: Whether to disable transitive dependency resolution.
- `allow-no-package-sources`: Treat OSV-Scanner's `No package sources found` result as a successful no-op.
- `verbosity`: OSV-Scanner log verbosity.
- `additional-args`: Optional newline-delimited arguments passed to OSV-Scanner.
- `fail-on-vulnerabilities`: Whether the workflow fails after reports upload when OSV-Scanner returns a non-zero result.
- `sarif-category`: GitHub Code Scanning category for the uploaded report.
- `artifact-retention-days`: Number of days to retain the SARIF artifact.
- `pipeline-templates-ref`: Git ref used to retrieve the shared `osv-scan.sh` script. This should match the reusable workflow ref.

## Additional arguments

The central workflow owns the SARIF output format and output path.

Do not provide any of the following through `additional-args`:

```text
--format
--output
--output-file
```

For example, a caller can provide a supported additional scanner option:

```yaml
additional-args: |-
  --lockfile=./go.mod
```

Repository-specific OSV-Scanner configuration should remain in the consuming repository and be passed with `config-path`.

## No package sources

The default behavior is:

```yaml
allow-no-package-sources: false
```

This is appropriate for application repositories. A missing dependency source may indicate that the configured scan path is wrong, that the repository is unexpectedly missing its lockfile, or that the workflow is not applicable.

For a repository that intentionally has no supported dependency metadata, use:

```yaml
allow-no-package-sources: true
```

This allows the workflow to succeed when OSV-Scanner reports no package sources, while preserving normal vulnerability detection if supported dependency metadata is added later.

> [!NOTE]
> Use this sparingly. Prefer not calling the OSV workflow at all when a repository has no dependencies to scan. The scan will still occur, but it will never find any results and just wastes runner minutes/pipeline runtime.

## Example use

This scans the complete consuming repository recursively:

```yaml
---
name: OSV Scan

on:
  pull_request:
  push:
    branches:
      - main
  schedule:
    ## Every day at 01:00 UTC.
    - cron: "0 1 * * *"
  workflow_dispatch:

permissions:
  actions: read
  contents: read
  security-events: write

jobs:
  osv-scan:
    uses: redjax/PipelineTemplates/.github/workflows/osv-scan.yml@main
    with:
      osv-scanner-version: "2.5.0"
      source: "."
      recursive: true
      fail-on-vulnerabilities: true
      sarif-category: "osv-scanner"
      artifact-retention-days: 30
      pipeline-templates-ref: "main"
```

This uses a repository-local OSV-Scanner configuration and disables transitive dependency resolution:

```yaml
jobs:
  osv-scan:
    uses: redjax/PipelineTemplates/.github/workflows/osv-scan.yml@main
    with:
      osv-scanner-version: "2.5.0"
      source: "."
      recursive: true
      config-path: ".osv-scanner.toml"
      no-resolve: true
      verbosity: "debug"
      fail-on-vulnerabilities: true
      pipeline-templates-ref: "main"
```

This scans a specific application directory:

```yaml
jobs:
  osv-scan:
    uses: redjax/PipelineTemplates/.github/workflows/osv-scan.yml@main
    with:
      osv-scanner-version: "2.5.0"
      source: "apps/go-example"
      recursive: true
      fail-on-vulnerabilities: true
      pipeline-templates-ref: "main"
```

This permits a successful no-op when no supported package source exists:

```yaml
jobs:
  osv-scan:
    uses: redjax/PipelineTemplates/.github/workflows/osv-scan.yml@main
    with:
      osv-scanner-version: "2.5.0"
      source: "."
      recursive: true

      ## Use only when this repository intentionally has no supported
      #  package manifest, lockfile, SBOM, or dependency metadata.
      allow-no-package-sources: true

      fail-on-vulnerabilities: true
      pipeline-templates-ref: "main"
```

When calling a released workflow version, use the matching ref for the shared script:

```yaml
jobs:
  osv-scan:
    uses: redjax/PipelineTemplates/.github/workflows/osv-scan.yml@v1
    with:
      pipeline-templates-ref: "v1"
```
