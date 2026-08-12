# Forgejo Actions

Documentation for the [Forgejo Actions reusable workflows](../../../.forgejo/workflows/) and [custom actions](../../../.forgejo/actions/) in this repository.

Forgejo Actions workflows are stored in the `.forgejo/workflows/` directory. Unlike GitHub Actions, which requires workflows to live in `.github/workflows/`, Forgejo uses `.forgejo/workflows/` as the primary location for workflow definitions.

This repository provides reusable Forgejo workflows and composite actions intended to be imported by consuming repositories. Workflows are designed to keep application repositories small by moving common CI/CD logic into PipelineTemplates.

Each reusable workflow has documentation describing:

- The purpose of the workflow.
- Supported inputs.
- Expected repository layout.
- Example usage from a consuming repository.

Each [Forgejo action](../../../.forgejo/actions/) has its own embedded documentation.

## Workflow Organization

Forgejo workflow files are grouped by purpose:

- `*-pr-*.yml` workflows validate changes before merging.
- `*-build.yml` workflows build application artifacts.
- `*-release.yml` workflows handle release workflows.
- `*-main.yml` workflows are orchestration pipelines that combine multiple reusable workflows into a complete CI/CD process.

Workflows ending in `*-main.yml` are intended to be entry points for consuming repositories. They generally coordinate tasks such as:

- Versioning.
- Building.
- Testing.
- Packaging.
- Publishing.

Individual reusable workflows are usually responsible for one focused task.

## Consuming Repository Usage

A consuming repository can call a reusable workflow by referencing the workflow file and a Git reference:

```yaml
jobs:
  build:
    uses: redjax/PipelineTemplates/.forgejo/workflows/example.yml@main
    with:
      example-input: value
```

The consuming repository provides repository-specific configuration through workflow inputs while PipelineTemplates manages the shared automation logic.
