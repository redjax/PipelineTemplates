# Renovate Pipeline <!-- omit in toc -->

Run [Renovate](https://github.com/renovatebot/renovate) against a Gitlab repository. The pipeline runs Renovate against the consuming Gitlab project, creates and manages Renovate branches and merge requests, and manages a "Dependency Dashboard" issue.

If the consuming repository provides a `renovate.json`, the pipeline will use it. Otherwise it falls back to the [default `config/renovate.default.json` config in this repository](../../../../../config/renovate/default.json).

## Table of Contents <!-- omit in toc -->

- [Authentication](#authentication)
- [Usage](#usage)
- [Create a Schedule](#create-a-schedule)
- [Repository Configuration](#repository-configuration)
- [Pipeline Inputs](#pipeline-inputs)
- [Run Modes](#run-modes)
- [Default Configuration](#default-configuration)
- [Security Notes](#security-notes)
- [Troubleshooting](#troubleshooting)
  - [`Missing required masked CI/CD variable: RENOVATE_TOKEN`](#missing-required-masked-cicd-variable-renovate_token)
  - [`GH_API_TOKEN is not set`](#gh_api_token-is-not-set)
  - [No repository configuration found](#no-repository-configuration-found)
  - [Pipeline does not contain a Renovate job](#pipeline-does-not-contain-a-renovate-job)

## Authentication

This pipeline requires the following secrets:

- `RENOVATE_TOKEN`: A Gitlab "legacy" token with `api` scope.
  - Renovate uses this token to read repository metadata, create branches and
    commits, and open or update merge requests and Dependency Dashboard issues.
  - The token owner must have at least the Developer role in every repository
    that Renovate manages.
- `GH_API_TOKEN` (optional): A GitHub PAT with API `read` access.
  - Used for looking up GitHub changelogs, tags, releases, and dependency
    metadata.
  - Used to authenticate the PipelineTemplates clone when the consuming
    repository does not contain its own `renovate.json`.
  - If omitted, the pipeline clones the public PipelineTemplates repository
    anonymously and Renovate can still run, but GitHub API lookups may be
    rate-limited.

Add secrets in the Gitlab repository UI, under Settings > CI/CD > Variables. Mark the secret tokens as "Masked and hidden", and ensure the "Protect variable" checkbox is selected.

> [!NOTE]
> Protected variables are available only to pipelines that run against protected branches or protected tags. Protect the target branch, normally `main`, before enabling scheduled Renovate runs.

## Usage

Create or update `.gitlab-ci.yml` in the consuming repository:

```yaml
---
stages:
  - maintenance

include:
  - remote: "https://raw.githubusercontent.com/redjax/PipelineTemplates/main/.gitlab/maint/renovate.yml"
    inputs:
      stage: maintenance
      mode: run
      log-level: info
      config-file: renovate.json
      require-config: optional
      github-template-repository: redjax/PipelineTemplates
      pipelinetemplates-ref: main
      base-branches: main
      use-base-branch-config: false
```

Gitlab supports including pipeline configuration from external YAML files. Use a GitHub tag or commit SHA instead of `main` to pin git clone to a specific release or commit.

For example, pin the central template to a commit short SHA:

```yaml
include:
  - remote: "https://raw.githubusercontent.com/redjax/PipelineTemplates/b832db5/.gitlab/maint/renovate.yml"
    inputs:
      stage: maintenance
      mode: run
      pipelinetemplates-ref: b832db5
      base-branches: main
```

> [!NOTE]
> Keep the remote include ref and `pipelinetemplates-ref` aligned. The first selects the Renovate pipeline definition, the second selects the revision used when the pipeline falls back to the central default Renovate configuration.

If you have existing pipeline jobs in the consuming Gitlab repository, you can use Gitlab's `include:` to split jobs under a `.gitlab` directory. For example, with this `.gitlab-ci.yml` at the repo root:

```yaml
---
workflow:
  rules:
    ## Run Renovate from a configured GitLab pipeline schedule.
    - if: $CI_PIPELINE_SOURCE == "schedule"
    ## Allow an intentional manual invocation from Build > Pipelines.
    - if: $CI_PIPELINE_SOURCE == "web"
    ## Do not create pipelines for pushes, merge requests, API triggers, or
    #  other pipeline sources.
    - when: never

stages:
  - maintenance

include:
  - local: "/.gitlab/renovate.yml"
```

and this `.gitlab/renovate.yml`:

```yaml
---
include:
  - remote: "https://raw.githubusercontent.com/redjax/PipelineTemplates/main/.gitlab/maint/renovate.yml"
    inputs:
      stage: maintenance
      image: renovate/renovate:<pinned-version>
      mode: run
      log-level: info
      config-file: renovate.json
      require-config: optional
      github-template-repository: redjax/PipelineTemplates
      pipelinetemplates-ref: main
      base-branches: main
      use-base-branch-config: false
      runner-tags: []
```

The main pipeline will run every time, but renovate will only run when its conditions are met.

## Create a Schedule

Renovate runs only for scheduled and manually started pipelines. Create a schedule in the consuming Gitlab project:

1. Open Build > Pipeline schedules.
2. Select New schedule (or "Create a new pipeline schedule" if none exist).
3. Choose the protected target branch, usually `main`.
4. Choose a schedule, such as weekly:

   ```text
   17 3 * * 1
   ```

5. Save the schedule.

The example runs at 03:17 every Monday in the project’s configured timezone.

To run Renovate immediately, open Build > Pipelines, select "Run pipeline", choose a protected branch, and start the pipeline.

## Repository Configuration

A consuming repository may define its own `renovate.json` at its root. When that file exists, Renovate uses it.

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
    "dependencyDashboard": true
}
```

If the repository does not contain `renovate.json`, the pipeline clones `PipelineTemplates` and uses the [`default.json` Renovate config](https://github.com/redjax/PipelineTemplates/blob/main/config/renovate/default.json).

Set `require-config: required` if the consuming repository must provide and maintain its own `renovate.json`.

## Pipeline Inputs

| Input                        | Default                              | Description                                                                  |
| ---------------------------- | ------------------------------------ | ---------------------------------------------------------------------------- |
| `stage`                      | `maintenance`                        | Gitlab stage containing the Renovate job                                     |
| `image`                      | `renovate/renovate:<pinned-version>` | Renovate container image                                                     |
| `mode`                       | `run`                                | Renovate execution mode: `extract`, `lookup`, or `run`                       |
| `log-level`                  | `info`                               | Renovate log level: `debug`, `info`, `warn`, or `error`                      |
| `config-file`                | `renovate.json`                      | Repository-relative path to a local Renovate configuration file              |
| `require-config`             | `optional`                           | Repository configuration policy: `required`, `optional`, or `ignored`        |
| `github-template-repository` | `redjax/PipelineTemplates`           | GitHub repository containing PipelineTemplates                               |
| `pipelinetemplates-ref`      | `main`                               | PipelineTemplates branch, tag, or commit SHA used for fallback configuration |
| `base-branches`              | Empty                                | Comma-separated Renovate base branches                                       |
| `use-base-branch-config`     | `false`                              | Load Renovate configuration from the target base branch                      |
| `runner-tags`                | Empty                                | Gitlab runner tags used to select an eligible runner                         |

Example using a dedicated runner and a non-default base branch:

```yaml
include:
  - remote: "https://raw.githubusercontent.com/redjax/PipelineTemplates/main/.gitlab/maint/renovate.yml"
    inputs:
      stage: maintenance
      mode: run
      base-branches: develop
      runner-tags:
        - docker
        - linux
```

## Run Modes

| Mode      | `RENOVATE_DRY_RUN` value | Behavior                                                                                                |
| --------- | ------------------------ | ------------------------------------------------------------------------------------------------------- |
| `extract` | `extract`                | Extracts dependencies and reports what Renovate discovers without creating updates                      |
| `lookup`  | `lookup`                 | Looks up available dependency updates without creating branches, commits, issues, or merge requests     |
| `run`     | Unset                    | Normal Renovate execution; creates or updates branches, Dependency Dashboard issues, and merge requests |

Start with `extract` or `lookup` while validating a new repository:

```yaml
include:
  - remote: "https://raw.githubusercontent.com/redjax/PipelineTemplates/main/.gitlab/maint/renovate.yml"
    inputs:
      mode: lookup
```

Change to `run` when the dependency detection and Renovate configuration look
correct.

## Default Configuration

The PipelineTemplates default configuration is used only when the consuming repository does not define the requested local configuration file.

The fallback configuration path is:

```text
config/renovate/default.json
```

Repository-local configuration takes precedence. This allows a repository to use the central baseline by default while opting into repository-specific package rules, grouping, labels, schedules, or automerge policy later.

## Security Notes

`RENOVATE_TOKEN` has significant write capability. Renovate uses the identity associated with this token when it creates branches, commits, Dependency Dashboard issues, and merge requests.

Use these safeguards:

- Store `RENOVATE_TOKEN` and `GH_API_TOKEN` as masked and protected variables.
- Run Renovate only against protected branches.
- Restrict who can modify `.gitlab-ci.yml` and the Renovate include
  configuration on protected branches.
- Pin the remote template URL to a reviewed PipelineTemplates tag or commit SHA.
- Set a token expiration date and rotate both tokens before expiration.
- Do not print environment variables, Git remotes, or token values in CI logs.

For normal runs, Renovate requires a Gitlab token with the `api` scope and a token identity with Developer access to each target project. For extra protection, you could create an additional Gitlab bot account, i.e. `<your-username>-renovate-bot` and add it as a "Developer" to the repo(s) managed by Renovate. Create a legacy PAT with only the `api` permission selected, and use this account to run the Renovate pipeline job.

## Troubleshooting

### `Missing required masked CI/CD variable: RENOVATE_TOKEN`

Add `RENOVATE_TOKEN` in Settings > CI/CD > Variables.

Confirm that:

- The token has Gitlab `api` scope.
- The variable is available for the pipeline target branch.
- If the variable is protected, the target branch is protected.
- The token owner has Developer access to the consuming repository.

### `GH_API_TOKEN is not set`

This warning does not stop Renovate.

Add `GH_API_TOKEN` to avoid GitHub API rate limiting and to authenticate `PipelineTemplates` cloning if the GitHub repository later becomes private. Renovate recommends `RENOVATE_GITHUB_COM_TOKEN` for GitHub metadata lookups when it runs from a non-GitHub platform. The pipeline maps `GH_API_TOKEN` to that standard Renovate variable automatically.

### No repository configuration found

The pipeline could not find either:

```text
renovate.json
```

in the consuming repository, or:

```text
config/renovate/default.json
```

in the selected PipelineTemplates revision.

Add a repository-local `renovate.json`, or verify that `pipelinetemplates-ref` points to a PipelineTemplates branch, tag, or commit containing the default configuration.

### Pipeline does not contain a Renovate job

The job runs only for:

```text
CI_PIPELINE_SOURCE == "schedule"
CI_PIPELINE_SOURCE == "web"
```

Create a pipeline schedule or use "Run pipeline". Push and merge-request pipelines intentionally omit the Renovate job.
