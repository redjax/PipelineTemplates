# Trivy Scan <!-- omit in toc -->

The [`trivy-scan` reusable workflow](../../../../../.github/workflows/trivy-scan.yml) runs centrally managed [Trivy](https://github.com/aquasecurity/trivy) security scans against a calling GitHub repository.

It provides a generic security-scanning baseline for applications, services, scripts, infrastructure repositories, and monorepos. By default, it scans the calling repository filesystem for dependency vulnerabilities, exposed secrets, and misconfigurations.

The workflow uses shared, platform-neutral scripts from `PipelineTemplates`:

- [`trivy-scan.sh`](../../../../../shared/scripts/ci-cd/security/trivy-scan.sh)
- [`install-trivy.sh`](../../../../../shared/scripts/bash/installers/install-trivy.sh)

## Table of Contents <!-- omit in toc -->

- [Default behavior](#default-behavior)
- [Inputs](#inputs)
- [Outputs](#outputs)
- [Permissions](#permissions)
- [Scan types](#scan-types)
  - [Filesystem](#filesystem)
  - [Container image](#container-image)
- [Reports and policy](#reports-and-policy)
- [Configuration](#configuration)
- [Examples](#examples)
  - [Minimal repository scan](#minimal-repository-scan)
  - [Feature-branch validation](#feature-branch-validation)
  - [Enforced application scan](#enforced-application-scan)
  - [Monorepo service scan](#monorepo-service-scan)
  - [Container image scan](#container-image-scan)
  - [Immutable release pinning](#immutable-release-pinning)

## Default behavior

With no caller-provided inputs, the workflow:

- Checks out the calling repository.
- Checks out `redjax/PipelineTemplates` at the configured `pipelinetemplates-ref` (default: `main`).
- Installs Trivy version provided by the consuming repository.
- Runs a filesystem scan against `.`.
- Enables vulnerability, secret, and misconfiguration scanners.
- Includes `HIGH` and `CRITICAL` severity findings.
- Excludes vulnerabilities that have no available fix.
- Generates JSON and SARIF reports.
- Uploads scan reports as a workflow artifact.
- Attempts to publish SARIF findings to GitHub Code Scanning.
- Does not fail the workflow because of findings unless `fail-on-findings` is enabled.

The default is intentionally non-blocking. This allows repositories to adopt centralized scanning, review their baseline findings, and tune repository-specific configuration before enforcing a failure policy.

## Inputs

| Input                     | Type      |                                    Default | Description                                                                   |
| ------------------------- | --------- | -----------------------------------------: | ----------------------------------------------------------------------------- |
| `pipelinetemplates-ref`   | `string`  |                                     `main` | Branch, tag, or commit SHA used to check out shared PipelineTemplates scripts |
| `trivy-version`           | `string`  | (the most recent version Renovate selects) | Trivy release version to install, without a leading `v`                       |
| `scan-type`               | `string`  |                               `filesystem` | Target type: `filesystem` or `image`                                          |
| `scan-path`               | `string`  |                                        `.` | Repository-relative target path for filesystem scans                          |
| `image-ref`               | `string`  |                                      Empty | Image name, tag, or digest for image scans                                    |
| `scanners`                | `string`  |                    `vuln,secret,misconfig` | Comma-separated Trivy scanners to enable                                      |
| `severity`                | `string`  |                            `HIGH,CRITICAL` | Comma-separated severity levels to report                                     |
| `ignore-unfixed`          | `boolean` |                                     `true` | Exclude vulnerabilities without an available fix                              |
| `config-path`             | `string`  |                                      Empty | Optional repository-relative Trivy configuration-file path                    |
| `skip-dirs`               | `string`  |                                      Empty | Optional comma-separated directories excluded from filesystem scans           |
| `fail-on-findings`        | `boolean` |                                    `false` | Fail after report publication when findings exist                             |
| `artifact-retention-days` | `number`  |                                       `30` | Number of days to retain Trivy report artifacts                               |

## Outputs

| Output          | Description                                                                                 |
| --------------- | ------------------------------------------------------------------------------------------- |
| `finding-count` | Number of vulnerability, secret, and misconfiguration findings in the generated JSON report |
| `has-findings`  | `true` when the scan reported one or more findings; otherwise `false`                       |
| `json-report`   | Runner-local path to the generated JSON report                                              |
| `sarif-report`  | Runner-local path to the generated SARIF report                                             |

The report-path outputs are primarily useful to steps within the reusable workflow itself. Calling workflows should retrieve reports from the uploaded artifact rather than relying on runner-local paths.

## Permissions

The calling workflow should grant the following permissions:

```yaml
permissions:
  contents: read
  security-events: write
```

`contents: read` allows repository checkout.

`security-events: write` allows the reusable workflow to upload the SARIF report to GitHub Code Scanning. The scan and artifact upload can still run when SARIF publication is unavailable, such as in some pull-request workflows from forks.

## Scan types

### Filesystem

Filesystem scanning is the default mode:

```yaml
with:
  scan-type: filesystem
  scan-path: "."
```

Use this mode for most repositories, including Go, Python, PowerShell, Bash, application, service, and infrastructure repositories.

For monorepos, scan the complete repository by default. Use `scan-path` when a service requires an independent scan, report artifact, or enforcement policy:

```yaml
with:
  scan-type: filesystem
  scan-path: services/some-service
```

### Container image

Image scanning requires `scan-type: image` and a non-empty `image-ref`:

```yaml
with:
  scan-type: image
  image-ref: ghcr.io/username/some-service:1.4.0
```

The image must be accessible from the reusable workflow runner. For private registry images, configure authentication in the calling workflow or use a registry identity available to the runner.

An image built in a separate job is not automatically available to this reusable-workflow job. Push the image to an accessible registry before scanning, or build and scan in the same runner job.

## Reports and policy

The workflow creates two report formats:

| Report                            | Purpose                                         |
| --------------------------------- | ----------------------------------------------- |
| `trivy-<scan-type>-results.json`  | Machine-readable raw Trivy findings             |
| `trivy-<scan-type>-results.sarif` | GitHub Code Scanning-compatible security report |

Reports are uploaded as an artifact named:

```text
trivy-<scan-type>-scan-results
```

For example, a filesystem scan uploads:

```text
trivy-filesystem-scan-results
```

The workflow uploads reports before evaluating `fail-on-findings`. This ensures findings remain available for investigation even when the final policy step fails.

Enable enforcement after a repository has reviewed and addressed its existing baseline:

```yaml
with:
  fail-on-findings: true
```

A finding is not the same as a scanner execution failure:

| Outcome                                           | Workflow behavior            |
| ------------------------------------------------- | ---------------------------- |
| Trivy finds no matching results                   | Succeeds                     |
| Trivy finds results and `fail-on-findings: false` | Succeeds and uploads reports |
| Trivy finds results and `fail-on-findings: true`  | Uploads reports, then fails  |
| Trivy cannot install, verify, or run              | Fails immediately            |

## Configuration

Trivy works without a repository-specific configuration file. Use the default detector set unless a repository has a clear need for custom configuration.

To provide a repository-local Trivy configuration file:

```yaml
with:
  config-path: ".trivy.yaml"
```

The configuration file must exist in the calling repository.

Exclude generated content, vendored dependencies, or intentionally unsupported paths with `skip-dirs`:

```yaml
with:
  skip-dirs: ".git,node_modules,vendor,dist,build"
```

Use a comma-separated list with no shell quoting or escaping requirements.

Trivy secret scanning provides broad secret-pattern coverage. Continue using the centralized TruffleHog workflow as the primary credential-verification control when verified-secret detection is required.

## Examples

### Minimal repository scan

```yaml
---
name: Trivy Security Scan

on:
  pull_request:
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read
  security-events: write

jobs:
  trivy:
    uses: redjax/PipelineTemplates/.github/workflows/trivy-scan.yml@main
```

### Feature-branch validation

Keep the reusable workflow ref and shared-script ref aligned when testing a template feature branch:

```yaml
jobs:
  trivy:
    uses: redjax/PipelineTemplates/.github/workflows/trivy-scan.yml@feat/some-feature-name
    with:
      pipelinetemplates-ref: feat/some-feature-name
```

### Enforced application scan

```yaml
jobs:
  trivy:
    uses: redjax/PipelineTemplates/.github/workflows/trivy-scan.yml@main
    with:
      pipelinetemplates-ref: v1
      fail-on-findings: true
      severity: "HIGH,CRITICAL"
      ignore-unfixed: true
```

### Monorepo service scan

```yaml
jobs:
  payments:
    uses: redjax/PipelineTemplates/.github/workflows/trivy-scan.yml@main
    with:
      pipelinetemplates-ref: main
      scan-type: filesystem
      scan-path: services/some-service
      fail-on-findings: true

  notifications:
    uses: redjax/PipelineTemplates/.github/workflows/trivy-scan.yml@main
    with:
      pipelinetemplates-ref: main
      scan-type: filesystem
      scan-path: services/some-other-service
      fail-on-findings: true
```

### Container image scan

```yaml

---jobs:
  trivy:
    uses: redjax/PipelineTemplates/.github/workflows/trivy-scan.yml@main
    with:
      pipelinetemplates-ref: main
      scan-type: image
      image-ref: ghcr.io/username/some-service:${{ github.sha }}
      scanners: "vuln,secret,misconfig"
      severity: "HIGH,CRITICAL"
      fail-on-findings: true
```

### Immutable release pinning

For the strongest reproducibility, use the same immutable commit SHA for both references:

```yaml
---
jobs:
  trivy:
    uses: redjax/PipelineTemplates/.github/workflows/trivy-scan.yml@<commit-sha>
    with:
      pipelinetemplates-ref: <commit-sha>
      fail-on-findings: true
```
