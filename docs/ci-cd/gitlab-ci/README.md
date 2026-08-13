# Gitlab CI/CD <!-- omit in toc -->

Documentation for the [Gitlab CI/CD pipeline templates](https://docs.gitlab.com/ci/) in this repository.

Gitlab CI/CD pipeline templates are stored in the `.gitlab/` directory. Unlike Github Actions and Forgejo Actions, Gitlab uses a root `.gitlab-ci.yml` file as the default pipeline entrypoint. That root file can include local or remote YAML configuration files, allowing consuming repositories to keep their entrypoint small while importing centralized `PipelineTemplates` jobs.

This repository provides reusable Gitlab CI/CD configuration templates intended to be imported by consuming repositories. Templates are designed to keep application repositories small by moving common CI/CD logic into `PipelineTemplates`.

Each reusable template has documentation describing:

- The purpose of the template.
- Supported CI/CD inputs.
- Required CI/CD variables and authentication.
- Expected repository layout.
- Example usage from a consuming repository.
- Scheduling or pipeline-trigger requirements.

## Pipeline Organization

Gitlab CI/CD template files are grouped by purpose:

- `maint/` contains maintenance pipelines, such as Renovate.
- `quality/` contains code-quality, linting, formatting, and security pipelines.
- `build/` contains build and packaging pipelines.
- `release/` contains release and publishing pipelines.
- `deploy/` contains deployment pipelines.

Individual templates are responsible for one focused task. Consuming repositories compose templates through Gitlab `include` directives.

The primary Gitlab CI/CD entrypoint remains the consuming repository's root `.gitlab-ci.yml` file. It can define stages and pipeline-level rules, then include repository-local configuration files under `.gitlab/`.

## Consuming Repository Usage

A consuming repository should keep a minimal root `.gitlab-ci.yml` file, i.e.:

```yaml
---
workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "schedule"
    - if: $CI_PIPELINE_SOURCE == "web"
    - when: never

stages:
  - maintenance

include:
  - local: "/.gitlab/renovate.yml"
```

Repository-local configuration can then import a centralized `PipelineTemplates` template. For example, `.gitlab/renovate.yml` may import the Renovate pipeline:

```yaml
---
include:
  - remote: "https://raw.githubusercontent.com/redjax/`PipelineTemplates`/main/.gitlab/maint/renovate.yml"
    inputs:
      stage: maintenance
      mode: run
      base-branches: main
      pipelinetemplates-ref: main
```

Gitlab supports external and local CI/CD configuration includes. Pin remote template references to a reviewed `PipelineTemplates` release tag or commit SHA after validating the template.

## CI/CD Inputs

Gitlab CI/CD templates in this repository use `spec:inputs` to define a template interface. Inputs allow consuming repositories to provide configuration such as:

- Pipeline stage.
- Container image version.
- Execution mode.
- Scan or target path.
- Base branch.
- Log level.
- Shared-template revision.
- Runner tags.

For example, a consuming repository can configure a centralized template with:

```yaml
include:
  - remote: "https://raw.githubusercontent.com/redjax/`PipelineTemplates`/main/.gitlab/maint/renovate.yml"
    inputs:
      stage: maintenance
      mode: lookup
      log-level: debug
      base-branches: main
```

## CI/CD Variables

Consuming repositories provide credentials and other sensitive configuration through Gitlab CI/CD variables. Add repository variables in a repository's Settings > CI/CD > Variables.

Store secrets as "Masked and hidden" variables. Mark sensitive variables as "Protected" when they should be available only to pipelines running against protected branches or tags. For example, the Renovate template requires `RENOVATE_TOKEN` and optionally `GH_API_TOKEN`, each of which are secret API token values.

Refer to each pipeline template's documentation for its required variables, token scopes, and access requirements. Protected variables are only exposed to pipelines for protected branches or tags.
