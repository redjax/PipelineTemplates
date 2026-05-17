# Github CI/CD

Documentation for Github Actions and [reusable workflows](./workflows/).

> [!NOTE]
> You can only call Github pipelines from this repository if the PipelineTemplates repository is hosted on Github. The Github platform will not import workflows from a a repository on another plattform.
>
> Additionally, workflow definitions must be stored in a [`.github/workflows/` directory](../../../.github/workflows/). Github [requires reusable workflows to exist at that path](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows), and will not load workflows from other directories.

## Usage

To [call a workflow](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows#calling-a-reusable-workflow) from this repository, add a `uses:` line with the path to a workflow and its version tag. For example, to call the [`demo-hello.yml` workflow](../../../.github/workflows/demo-hello.yml):

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
