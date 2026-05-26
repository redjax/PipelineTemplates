# PipelineTemplates Development Documentation

`PipelineTemplates` is a monorepo, which changes the way some things work. For instance, when calling a Github Action, instead of just using the `username/repo-name` to call the action, you need to call pipelines with this syntax:

```yaml
uses: redjax/PipelineTemplates/.github/actions/<action-name>@gh/<tag-name>/v0.0.1
```

Tags are created each time a component is updated. When an individual component is called, the whole repository is cloned at the state it was when the tag was created, and then the calling pipeline scopes to the Action it is using.

> [!NOTE]
> I debated how to version this repository for a while, and saw 2 choices for effective versioning paths:
>
> - Version the entire repository as a single unit
>   - The positive of this method is that versioning would be simpler, but more constant.
>   - Every time a component changed, the entire repository would be 'bumped'.
>   - This would require much more constant bumping in calling pipelines, and would make the version a moving target.
> - Version each individual pipeline component (Github Actions, Gitlab Components, etc) separately
>   - While this method required much more up front work, such as writing scripts to detect each component with a `VERSION` file and the pipeline logic for determining when to bump, it also kept tags isolated to the component that was changed.
>   - This method creates a ton of git tags, and I am still considering if this is the best method of versioning, but while there is a manageable number of tags, it makes things easier on the calling pipeline end.

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

### Example: Demo hello Github Action

The [`hello` Github Action](../../.github/actions/hello/) is a simple pipeline I started the repository with. It accepts an input message (or sets a default) and prints/echoes it to the console.

The pipeline accepts a single input: `message`. This can be anything you want to print in the pipeline, and the default is `"hello from pipeline templates"`.

In the [`PipelineTemplates-test` repository](#pipelinetemplates-test-repo-setup), create a `.github/workflows` directory if it does not already exist. Then create a `test-hello.yml` pipeline that calls the `hello` Action defined in the `PipelineTemplates` repository. The calling pipeline exposes the `message` input to the `PipelineTemplates-test` pipeline, then passes the value through to the Github Action in `PipelineTemplates`.

```yaml
---
name: Test hello-world demo

on:
  workflow_dispatch:
    inputs:
      message:
        description: The message to print
        required: false
        type: string
        default: Hello from PipelineTemplates-test

jobs:
  call-template:
    runs-on: ubuntu-latest
    steps:
      - name: Print message
        uses: redjax/PipelineTemplates/.github/actions/hello@gh/hello/v0.0.1
        with:
          message: ${{ inputs.message }}

```

### Example: Call a Github Reusable Workflow

Github Reusable Workflows are pipelines you can call from other pipelines. They are different from Github Actions in that instead of being a component focused around a single task, reusable workflows define a full pipeline that might call other Actions or scripts, and can be called from other repositories.

> [!WARNING]
> Reusable workflows in the `PipelineTemplates` repository are not versioned like Github Action components. A calling pipeline will always use the latest version, unless a specific tag/ref is given.

Calling a reusable workflow is pretty similar to calling a Github Action:

```yaml
---
name: Test hello-world demo

on:
  workflow_dispatch:
    inputs:
      message:
        description: The message to print
        required: false
        type: string
        default: Hello from PipelineTemplates-test

jobs:
  call-template:
  uses: redjax/PipelineTemplates/.github/workflows/demo-hello.yml@feat/some-branchname  # Call the workflow at a specific branch
  with:
    message: ${{ inputs.message }}  # Pass the input message to the workflow
```
