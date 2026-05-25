# PipelineTemplates Development Documentation

## Testing pipelines

I have a separate repository, `PipelineTemplates-test`, where I create pipeline "stubs" that call pipelines and pipeline components defined in this repository. The test repository references a specific pipeline or component in this repository, using either a branch ref or specific tag. I trigger the pipelines in this repository to see how a pipeline in this repository would execute when called from a "real" repository.

The testing repository is equipped with code the pipeline can act on; for example, the repository has multiple Go and Python applications so I can test pipelines/components like the [`go-build` Github Action](../../.github/actions/go-build/).

Each pipeline/component in this repository should include a `README` file describing the pipeline's purpose, how to use it (params, repository requirements, etc), and an example pipeline stub the user can reference for calling it.
