# Renovate Pipeline <!-- omit in toc -->

The Renovate pipeline runs Renovate against a consuming repository to detect dependency updates and automatically manage dependency pull requests.

The workflow supports repository-specific `renovate.json` configuration, with a PipelineTemplates default configuration used when the consuming repository does not provide its own. It can run normally or in Renovate's `extract` and `lookup` dry-run modes for troubleshooting and configuration inspection.

> [!NOTE]
> This pipeline uses my [custom Forgejo runner image](https://github.com/redjax/Dockerfiles/tree/main/dockerfiles/ci/forgejo/automation/renovate).

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Secrets](#secrets)
- [Variables](#variables)
- [Example use](#example-use)
- [Repository configuration](#repository-configuration)
- [Troubleshooting modes](#troubleshooting-modes)

## Responsibilities

- Run Renovate using the `forgejo-renovate` runner image.
- Check-out the consuming repository.
- Check-out PipelineTemplates for the default Renovate configuration.
- Select the consuming repository's Renovate configuration when present.
- Fall back to the PipelineTemplates default configuration when no repository configuration exists.
- Support normal Renovate execution as well as `extract` and `lookup` dry-run modes.
- Configure Renovate to use the Forgejo platform and API endpoint.
- Authenticate Renovate using a Forgejo personal access token.
- Detect dependency updates and create or update pull requests.
- Apply the consuming repository's Renovate configuration, including package rules, automerge settings, grouping, and update policies.
- Optionally use a GitHub.com token for dependencies hosted on GitHub.com.
- Allow the Renovate configuration and target base branches to be overridden through workflow inputs.

## Inputs

- `mode`: Renovate execution mode. Supported values are `run`, `extract`, and `lookup`.
- `repository`: Target repository to process.
- `log-level`: Renovate log level.
- `config-file`: Path to the consuming repository's Renovate configuration. Defaults to `renovate.json`.
- `require-config`: Controls whether Renovate requires a configuration file.
- `autodiscover`: Enable Renovate repository autodiscovery.
- `pipelinetemplates-ref`: PipelineTemplates branch, tag, or commit containing the default Renovate configuration.
- `renovate-author-email`: Email address used for the Renovate Git author.
- `base-branches`: Optional list of Renovate base branches.
- `use-base-branch-config`: Use the Renovate configuration from the base branch.
- `forgejo-endpoint`: Forgejo API endpoint. Must end with `/api/v1`.

## Secrets

- `RENOVATE_TOKEN`: Required Forgejo personal access token used by Renovate to access repositories and manage issues and pull requests. The token requires repository read/write, issue read/write, and pull request read/write permissions.
- `GH_COM_TOKEN`: Optional GitHub.com token used when Renovate needs to access GitHub.com resources.

## Variables

The consuming repository must define the following repository variable:

- `FJ_ENDPOINT`: Forgejo API endpoint used by Renovate. The value must end with `/api/v1`.

For example:

```text
FJ_ENDPOINT=https://forgejo.example.com/api/v1
```

The variable is passed to the reusable workflow through the forgejo-endpoint input:

with:

```yaml
  forgejo-endpoint: ${{ vars.FJ_ENDPOINT }}
```

The workflow validates this value before running Renovate and fails if it is empty or does not end with /api/v1.

## Example use

This workflow is usually called from a consuming repository's scheduled Renovate workflow:

```yaml
---
name: Renovate

on:
  schedule:
    ## Run every 6 hours
    - cron: "0 3 * * *"
    - cron: "0 9 * * *"
    - cron: "0 15 * * *"
    - cron: "0 21 * * *"

  workflow_dispatch:

jobs:
  renovate:
    uses: redjax/PipelineTemplates/.forgejo/workflows/renovate.yml@main
    with:
      mode: run
      repository: ${{ github.repository }}
      log-level: info
      forgejo-endpoint: ${{ vars.FJ_ENDPOINT }}
      pipelinetemplates-ref: main
    secrets:
      RENOVATE_TOKEN: ${{ secrets.RENOVATE_TOKEN }}
      GH_COM_TOKEN: ${{ secrets.GH_COM_TOKEN }}
```

## Repository configuration

Consuming repositories can provide their own `renovate.json` at the repository root. When present, that configuration takes precedence over the PipelineTemplates default configuration.

For example:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:recommended"
  ],
  "labels": [
    "dependencies"
  ],
  "prConcurrentLimit": 5,
  "platformAutomerge": true,
  "dependencyDashboard": true
}
```

If `renovate.json` is not present, the workflow uses the [default Renovate config](../../../../../config/renovate/default.json`)

## Troubleshooting modes

The workflow supports two Renovate dry-run modes:

`extract`: Extract dependency information without performing updates.
`lookup`: Resolve and inspect dependency information without performing updates.
`run`: Perform the normal Renovate operation.

For example, a manual workflow dispatch can use:

```yaml
with:
  mode: extract
```

or:

```yaml
with:
  mode: lookup
```

Use `run` for normal scheduled or manually triggered Renovate execution.
