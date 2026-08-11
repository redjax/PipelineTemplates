# Govulncheck Scan <!-- omit in toc -->

The [`govulncheck` workflow](../../../../../.github/workflows/govulncheck.yml) discovers Go modules in a consuming repository and runs [`govulncheck`](https://go.dev/doc/tutorial/govulncheck) against every discovered or explicitly configured module.

The workflow supports a repository with a Go application at its root, repositories with one or more Go applications in subdirectories, or a mixture of both.

Each module receives separate SARIF, text, and stderr reports. SARIF results are uploaded to GitHub Code Scanning with unique categories per Go module.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Module discovery](#module-discovery)
- [Reports](#reports)
- [Example use](#example-use)

## Responsibilities

- Check-out the consuming repository.
- Check out the shared `govulncheck.sh` script from `PipelineTemplates`.
- Install the requested Go and Govulncheck versions.
- Discover every eligible `go.mod` file, unless the caller specifies module paths.
- Run Govulncheck SARIF and text scans for every discovered Go module.
- Upload one SARIF result per module to GitHub Code Scanning.
- Upload text, stderr, SARIF, and summary reports as workflow artifacts.
- Optionally fail when reachable Go vulnerabilities are found.
- Always fail when Govulncheck cannot successfully scan a discovered module.

## Inputs

- `go-version`: Go version used to install and run Govulncheck.
- `govulncheck-version`: Govulncheck version to install, i.e. `latest` or a Go module version such as `v1.1.4`.
- `module-paths`: Optional newline-delimited module directories containing `go.mod`.
- `exclude-module-paths`: Optional newline-delimited module directories to exclude during automatic discovery.
- `package-pattern`: Go package pattern passed to Govulncheck for each module.
- `fail-on-vulnerabilities`: Whether the workflow fails after report upload when reachable vulnerabilities are found.
- `sarif-category`: Category prefix used for GitHub Code Scanning results.
- `artifact-retention-days`: Number of days to retain Govulncheck reports.
- `pipeline-templates-ref`: Git ref used to retrieve the shared `govulncheck.sh` script. This should match the reusable workflow ref.

## Module discovery

When `module-paths` is empty, the workflow discovers `go.mod` files recursively.

For example, this repository layout produces two Govulncheck scans:

```text
.
├── go.mod
└── apps/
    └── go-example/
        └── go.mod
```

The discovered module directories are:

```text
.
apps/go-example
```

The workflow creates distinct GitHub Code Scanning categories for each module:

```text
govulncheck-root
govulncheck-apps--go-example
```

Use `module-paths` only when automatic discovery should be restricted to specific modules.

## Reports

The uploaded `govulncheck-reports` artifact contains output similar to:

```text
govulncheck-reports/
├── summary.env
├── sarif/
│   ├── root.sarif
│   └── apps--go-example.sarif
├── stderr/
│   ├── root-sarif.stderr
│   ├── root.stderr
│   ├── apps--go-example-sarif.stderr
│   └── apps--go-example.stderr
└── text/
    ├── root.txt
    └── apps--go-example.txt
```

`summary.env` contains aggregate scan state:

```text
module_count=2
vulnerability_module_count=0
error_module_count=0
has_vulnerabilities=false
has_errors=false
```

## Example use

This scans every Go module discovered in the repository:

```yaml
---
name: Govulncheck Scan

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
  govulncheck:
    uses: redjax/PipelineTemplates/.github/workflows/govulncheck.yml@main
    with:
      go-version: "stable"
      govulncheck-version: "latest"
      fail-on-vulnerabilities: true
      sarif-category: "govulncheck"
      artifact-retention-days: 30
      pipeline-templates-ref: "main"
```

This scans only explicitly selected Go modules:

```yaml
jobs:
  govulncheck:
    uses: redjax/PipelineTemplates/.github/workflows/govulncheck.yml@main
    with:
      module-paths: |-
        .
        apps/api
        apps/worker
      package-pattern: "./..."
      fail-on-vulnerabilities: true
      pipeline-templates-ref: "main"
```

This uses automatic discovery but excludes example and tool modules:

```yaml
jobs:
  govulncheck:
    uses: redjax/PipelineTemplates/.github/workflows/govulncheck.yml@main
    with:
      exclude-module-paths: |-
        examples/go-example
        tools/generator
      fail-on-vulnerabilities: true
      pipeline-templates-ref: "main"
```

When calling a released workflow version, use the same ref for the shared script:

```yaml
jobs:
  govulncheck:
    uses: redjax/PipelineTemplates/.github/workflows/govulncheck.yml@v1
    with:
      pipeline-templates-ref: "v1"
```
