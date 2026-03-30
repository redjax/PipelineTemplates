# PipelineTemplates - Development <!-- omit in toc -->

## Table of Contents <!-- omit in toc -->

- [Overview](#overview)
- [Github Actions and Reusable Workflows](#github-actions-and-reusable-workflows)
- [Testing Changes](#testing-changes)
  - [Examples](#examples)
    - [Github Action](#github-action)
    - [Gitlab Pipeline](#gitlab-pipeline)

## Overview

Pipelines created in this repository can be called/imported from other repositories to reduce code repetition and standardize processes. The [`manifests/version.yml` file](../manifests/versions.yml) tracks each pipeline's current version.

> [!NOTE]
> Each time you create a new template, i.e. a new file in `.github/workflows` or `gitlab/**`, you must add the initial tag to the `manifests/version.yml` file. The tag can be derived from the path:
>
> ```plaintext
> .github/workflows/demo-hello.yml -> github/demo-hello: v0.0.1
> gitlab/demo/hello.yml -> gitlab/demo/hello: v0.0.1
> ```

When the PipelineTemplates repository is hosted on Github, the [`pipelinetemplates-pullrequest.yml` pipeline](../.github/workflows/pipelinetemplates-pullrequest.yml) runs each time a PR to `main` is opened. It detects changes to individual pipeline files in any (known) path (`.github/workflows/`, `gitlab/**/`, etc), runs the [`release.sh` script](../.scripts/release.sh) which finds all changed pipeline files in the current PR, and bumps the version for changed files in the [`manifests/versions.yml` file](../manifests/versions.yml).

You can also manually bump a specific file's version tag using the [`manual-release.sh` script](../.scripts/manual-release.sh). You must manually push tags created by this script (`git push origin <tag_name>`).

## Github Actions and Reusable Workflows

Github has 2 kinds of pipelines, Actions and reusable workflows. Github Actions (or "custom actions") are like a step or set of steps packaged into a single callable step from other pipelines, where a reusable workflow is more of a traditional pipeline template.

- [Github Actions docs](https://docs.github.com/en/actions)
- [Github reusable workflows docs](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows)

Some notes Github Actions/reusable workflows:

- Github Actions must exist in `.github/actions/`
- Reusable workflows must exist in `.github/workflows/` dir

## Testing Changes

Sometimes you want to test a change to a pipeline before merging it into the `main` branch. Each pipeline in this repository is individually versioned and tagged, so to test a change to a pipeline, you can reference a specific branch, tag, or commit hash.

Create a testing repository, i.e. `redjax/PipelineTemplates-test`, and create a pipeline that calls the pipeline you want to test. You should generally use a commit hash, both for security and for testing a specific commit.

### Examples

#### Github Action

```yaml
---
name: Test specific branch of demo-hello

on:
  workflow_dispatch:

jobs:
  call-template:
    ## Pin to a specific version using @
    #
    # You can use a branch, i.e. feat/branch-name, a tag i.e. @github/demo-hello/v0.0.3
    #   or a full commit hash i.e. 26a452637eeb3a3e4a079b6ee153ad7c64bd22fc
    uses: redjax/PipelineTemplates/.github/workflows/demo-hello.yml@feat/branch-name
```

#### Gitlab Pipeline

```yaml
---
include:
  ## Gitlab can import from remote URLs. In this case, a Gitlab pipeline hosted in a repository on Github.
  #  Use Github's URL pattern to grab a specific version, in this case the gitlab/demo/hello/v0.0.1 git tag.
  #
  #  You can also use a branch name, i.e. ...redjax/PipelineTemplates/feat/branch-name/gitlab/demo/hello.yml,
  #  or a commit hash like:
  #    ...redjax/PipelineTemplates/3f6582715acb639ec5afb2db4a1784cd08e2a2eb/gitlab/demo/hello.yml
  - remote: 'https://raw.githubusercontent.com/redjax/PipelineTemplates/gitlab/demo/hello/v0.0.1/gitlab/demo/hello.yml'

variables:
  MESSAGE: "hello from the caller"
```
