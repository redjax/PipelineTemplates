# Gitlab Pipelines <!-- omit in toc -->

Documentation for [Gitlab pipelines](https://docs.gitlab.com/ci).

Gitlab can call pipelines from other repositories using the [`include:` keyword](https://docs.gitlab.com/ci/yaml/#include). Gitlab reads from a `.gitlab-ci.yml` file defined at the root of a repository.

You can [use the `include:` keyword to import external YAML in your pipeline](https://docs.gitlab.com/ci/yaml/includes/), which lets you split a pipeline up into steps stored locally, or import from a URL/ref:

```yaml
---
include:
  ## Change the 'gitlab/demo/hello/v0.0.1' tag when the remote pipeline is updated
  - remote: 'https://raw.githubusercontent.com/redjax/PipelineTemplates/gitlab/demo/hello/v0.0.1/gitlab/demo/hello.yml'

variables:
  ## The gitlab/demo/hello.yml pipeline expects a $MESSAGE var, and echoes that message when called
  MESSAGE: "hello from another repository"

```
