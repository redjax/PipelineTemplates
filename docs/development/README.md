# PipelineTemplates Development Documentation

## Testing pipelines

I have a separate repository, `PipelineTemplates-test`, where I create pipeline "stubs" that call pipelines and pipeline components defined in this repository. The test repository references a specific pipeline or component in this repository, using either a branch ref or specific tag. I trigger the pipelines in this repository to see how a pipeline in this repository would execute when called from a "real" repository.

The testing repository is equipped with code the pipeline can act on; for example, the repository has multiple Go and Python applications so I can test pipelines/components like the [`go-build` Github Action](../../.github/actions/go-build/).

Each pipeline/component in this repository should include a `README` file describing the pipeline's purpose, how to use it (params, repository requirements, etc), and an example pipeline stub the user can reference for calling it.

### PipelineTemplates-test repo setup

- Create a directory, i.e. `PipelineTemplates-test`
- `cd` into the directory and initialize a git repo with `git init -b main`
- Create an initial `.gitignore` file (it can be empty to start with)
- Create a `README.md` file with a simple title like `# PipelineTemplates-test`
- Add and commit everything and push to a Github repository you create
  - If you use another forge like Gitlab or Codeberg, push there instead

The rest of your setup depends on which forge you are hosting your pipelines in. I have not written per-forge documentation yet, I am primarily using Github, so at this stage you would create a `.github/workflows/` directory to prepare for defining pipelines that call this repository.
