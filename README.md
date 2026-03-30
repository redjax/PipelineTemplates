# Pipeline Templates <!-- omit in toc -->

Reusable pipeline templates for CI/CD technologies like Github Actions, Gitlab Pipelines, and Concourse CI.

## Usage

Each CI/CD platform has different ways of importing/including a workflow that exists in another repository. The sections below detail instructions for each platform, and detail any requirements or sharp edges specific to that platform.

### Github Actions

> [!NOTE]
> You can only call Github pipelines from this repository if the PipelineTemplates repository is hosted on Github. The Github platform will not import workflows from a a repository on another plattform.
>
> Additionally, workflow definitions must be stored in a [`.github/workflows/` directory](.github/workflows/). Github [requires reusable workflows to exist at that path](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows), and will not load workflows from other directories.

To [call a workflow](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows#calling-a-reusable-workflow) from this repository, add a `uses:` line with the path to a workflow and its version tag. For example, to call the [`demo-hello.yml` workflow](.github/workflows/demo-hello.yml):

```yaml
---
name: Test hello-world demo

on:
  workflow_dispatch:

jobs:
  call-template:
    ## Reusable workflows must be hosted on Github, so you omit the github.com/ portion of the URL.
    #  Call a specific tag/release of the pipeline with @
    uses: redjax/PipelineTemplates/.github/workflows/demo-hello.yml@github/demo-hello/v0.0.3
    with:
      message: Hello from PipelineTemplates-Test

```

### Gitlab

Gitlab can call pipelines from other repositories using the [`include:` keyword](https://docs.gitlab.com/ci/yaml/#include). Gitlab reads from a `.gitlab-ci.yml` file defined at the root of a repository. You can [use the `include:` keyword to import external YAML in your pipeline](https://docs.gitlab.com/ci/yaml/includes/), which lets you split a pipeline up into steps stored locally, or import from a URL/ref:

```yaml
---
include:
  ## Change the 'gitlab/demo/hello/v0.0.1' tag when the remote pipeline is updated
  - remote: 'https://raw.githubusercontent.com/redjax/PipelineTemplates/gitlab/demo/hello/v0.0.1/gitlab/demo/hello.yml'

variables:
  ## The gitlab/demo/hello.yml pipeline expects a $MESSAGE var, and echoes that message when called
  MESSAGE: "hello from anothe repository"

```
