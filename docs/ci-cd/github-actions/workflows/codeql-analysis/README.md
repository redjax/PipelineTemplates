# CodeQL Analysis <!-- omit in toc -->

The [`codeql-analysis` workflow](../../../../../.github/workflows/codeql-analysis.yml) runs [GitHub CodeQL](https://codeql.github.com/) analysis against a consuming repository and uploads results to GitHub Code Scanning.

The workflow does not define repository triggers, release behavior, or alert triage policy. The consuming repository controls when it runs, which languages CodeQL analyzes, and whether a traced build is required.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Example use](#example-use)

## Responsibilities

- Check-out the consuming repository.
- Initialize CodeQL for one or more requested languages.
- Optionally run caller-provided build commands between CodeQL initialization and analysis.
- Run CodeQL analysis.
- Upload CodeQL results to GitHub Code Scanning.

## Inputs

- `languages`: Comma-separated CodeQL languages to analyze, i.e. `go`, `python`, or `go,python`. Leave empty to use CodeQL language detection.
- `queries`: Optional CodeQL query additions, i.e. `+security-extended` or `+security-and-quality`.
- `run-build`: Whether to run caller-provided build commands between CodeQL initialization and analysis.
- `build-commands`: Newline-delimited build commands to run when `run-build` is enabled.
- `upload-sarif`: Whether CodeQL should upload results to GitHub Code Scanning.
- `fail-on-error`: Whether the workflow should fail when CodeQL initialization or analysis encounters an error.
- `category`: Optional GitHub Code Scanning category for the CodeQL result.

## Example use

The simplest version of this pipeline has an empty `languages` input, which allows CodeQL to detect supported languages:

```yaml
name: CodeQL Analysis

on:
  pull_request:
    types: [opened, synchronize, reopened]
    
jobs:
  codeql:
    uses: redjax/PipelineTemplates/.github/workflows/codeql-analysis.yml@main
    with:
      languages: ""
```

Analyze a Go repository without an explicit build phase:

```yaml
---
name: Code Quality Analysis

on:
  pull_request:
    paths:
      - "**/*.go"
      - "**/go.mod"
      - "**/go.sum"
  push:
    branches:
      - main
  schedule:
    ## Every Sunday at 01:00 UTC.
    - cron: "0 1 * * 0"
  workflow_dispatch:

permissions:
  actions: read
  contents: read
  security-events: write

jobs:
  codeql:
    uses: redjax/PipelineTemplates/.github/workflows/codeql-analysis.yml@main
    with:
      languages: "go"
```

For a mixed Go and Python repository that requires a traced build:

```yaml
---
name: Code Quality Analysis

on:
  pull_request:
    paths:
      - "**/*.go"
      - "**/go.mod"
      - "**/go.sum"
      - "**/*.py"
      - "**/pyproject.toml"
      - "**/requirements.txt"
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  actions: read
  contents: read
  security-events: write

jobs:
  codeql:
    uses: redjax/PipelineTemplates/.github/workflows/codeql-analysis.yml@main
    with:
      languages: "go,python"
      queries: "+security-extended"
      run-build: true
      build-commands: |-
        go build ./...
        python -m pytest
```
