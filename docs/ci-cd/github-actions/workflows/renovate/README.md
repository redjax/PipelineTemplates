# Renovate Pipeline <!-- omit in toc -->

The [`renovate`](../../../../../.github/workflows/renovate.yml) workflow runs Renovate against a consuming repository and either uses a repo-local `renovate.json` or falls back to the [central default config in `pipelinetemplates`](../../../../../config/renovate/default.json).

The workflow can be triggered manually or on a schedule from the consuming repository. It supports onboarding, dependency dashboard creation, and regular update runs.

If the consuming repository contains a `renovate.json` at the configured `config-file` path, that file is used. If no repo-local config is found, the workflow falls back to `pipelinetemplates/config/renovate/default.json`. The `run` mode performs a normal Renovate execution, `lookup` performs a lookup-style run without creating updates, and `extract` is for extraction-only behavior and does not create the normal Renovate outputs you would expect from a full run.

The default Renovate config extends `config:recommended`, adds the `dependencies` label, limits concurrency, groups non-major updates, and automerges minor, patch, and digest updates. The default configuration also creates a Renovate "dashboard" issue in the issue tracker.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Secrets](#secrets)
- [Example use](#example-use)
  - [Example Renovate config JSON files](#example-renovate-config-json-files)
    - [Docker config](#docker-config)
    - [NPM config](#npm-config)
    - [Python config](#python-config)
    - [Github Actions config](#github-actions-config)

## Responsibilities

- Check out the consuming repository.
- Check out `redjax/pipelinetemplates` to load the shared Renovate workflow config.
- Select a Renovate config file from the consuming repo if one exists.
- Fall back to the central Renovate config if no repo-local config is present.
- Run Renovate with the requested mode and log level.
- Create or update the Renovate setup PR, dependency dashboard issue, and update PRs as needed.

## Inputs

- `mode`: Renovate execution mode. Use `extract`, `lookup`, or `run`.
- `repository`: Target repository to process.
- `log-level`: Renovate log verbosity.
- `config-file`: Path to the consuming repository's local Renovate config.
- `require-config`: Controls how Renovate treats repository-local config.
- `autodiscover`: Whether Renovate should auto-discover repositories.
- `runner-image`: Runner label or image to use.
- `pipelinetemplates-ref`: Branch, tag, or commit to use for the shared workflow checkout.
- `renovate-author-email`: Email address Renovate uses for git commits.

## Secrets

- `renovate-token`: GitHub PAT used by Renovate to authenticate and create pull requests or issues (`RENOVATE_TOKEN`).
- `gh-api-token`: Optional GitHub API token used to reduce rate limiting (`GH_API_TOKEN`).

## Example use

This workflow is usually called by a scheduled or manually triggered workflow in the consuming repository:

> [!NOTE]
> A consuming repository can also override the email or point the workflow at a different config path if needed. To use a different email, either set a default for `renovate-author-email`, or hardcode it in the call to the central PipelineTemplates repository.

```yaml
---
name: Run Renovate

on:
  schedule:
    - cron: "0 3 * * *"
  workflow_dispatch:
    inputs:
      mode:
        description: "Renovate mode"
        required: false
        default: "lookup"
        type: choice
        options:
          - extract
          - lookup
          - run
      log-level:
        description: "Renovate log level"
        required: false
        default: "info"
        type: choice
        options:
          - info
          - debug
          - trace

permissions:
  contents: read
  pull-requests: write
  issues: write
  actions: write

jobs:
  renovate:
    uses: redjax/pipelinetemplates/.github/workflows/renovate.yml@feat/renovate-workflow
    with:
      mode: ${{ github.event_name == 'schedule' && 'run' || inputs.mode }}
      log-level: ${{ inputs.log-level || 'info' }}
      repository: ${{ github.repository }}
      config-file: renovate.json
      require-config: optional
      autodiscover: false
      runner-image: ubuntu-latest
      renovate-author-email: "5534031+redjax@users.noreply.github.com"
    secrets:
      renovate-token: ${{ secrets.RENOVATE_TOKEN }}
      gh-api-token: ${{ secrets.GH_API_TOKEN }}

```

### Example Renovate config JSON files

A consuming repository can provide its own `renovate.json` using the `config-file` input. If `renovate.json` is available in the consuming repo, the workflow will use that file instead of the default fallback in the PipelineTemplates repository.

Below are some example `renovate.json` configs you might use in the consuming repository.

#### Docker config

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "labels": ["dependencies", "renovate", "docker"],
  "packageRules": [
    {
      "matchManagers": ["dockerfile"],
      "matchUpdateTypes": ["patch", "digest"],
      "automerge": true
    }
  ]
}

```

#### NPM config

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "labels": ["dependencies", "renovate", "npm"],
  "packageRules": [
    {
      "matchManagers": ["npm"],
      "matchUpdateTypes": ["minor", "patch"],
      "automerge": true
    },
    {
      "matchManagers": ["npm"],
      "matchUpdateTypes": ["major"],
      "automerge": false
    }
  ]
}

```

#### Python config

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "labels": ["dependencies", "renovate", "python"],
  "packageRules": [
    {
      "matchManagers": ["pip_requirements", "poetry"],
      "matchUpdateTypes": ["patch", "minor"],
      "automerge": true
    },
    {
      "matchManagers": ["pip_requirements", "poetry"],
      "matchUpdateTypes": ["major"],
      "automerge": false
    }
  ]
}

```

#### Github Actions config

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "labels": ["dependencies", "renovate", "github-actions"],
  "packageRules": [
    {
      "matchManagers": ["github-actions"],
      "matchUpdateTypes": ["patch", "minor"],
      "automerge": true
    },
    {
      "matchManagers": ["github-actions"],
      "matchUpdateTypes": ["major"],
      "automerge": false
    }
  ]
}

```
