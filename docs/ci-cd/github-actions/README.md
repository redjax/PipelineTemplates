# Github Actions

Documentation for the [Github Actions reusable workflows](../../../.github/workflows/) in this repository.

Github is very finicky about where a pipeline lives; it *must* exist in the `.github/workflows/` path, at the root (no subdirectories). This makes organization a bit difficult, so each reusable workflow has a prefix describing its purpose, i.e. `pipelinetemplates-*.yml` are pipelines for this `PipelineTemplates` repository, `hugo-*.yml` are pipelines for working with Hugo sites, etc.

Workflows that end with `*-main.yml` are orchestration pipelines that call other Github Actions/reusable workflows. For example, the [`hugo-site-main.yml` pipeline](../../../.github/workflows/hugo-site-main.yml) is designed to handle versioning, building, tagging/releasing, and publishing a Hugo site, and only requires a small pipeline stub in the calling repository.

Note that each [Github action](../../../.github/actions/) has its own embedded documentation.

## Pipelines for This Repository

Pipeline files named `pipelinetemplates-*.yml` are automations that run for this `PipelineTemplates` repository. They are not meant to be imported/used in other repositories, they are meant to manage the `PipelineTemplates` repository itself. Those pipelines handle versioning, scanning, and releasing tasks for things like the [Github Actions](../../../.github/actions/) this repository defines.

To see documentation for specific workflows, check the [Github re-usable workflows documentation](./workflows/).

### Pipeline: Bump zero-versioned components

The [`pipelinetemplates-bump-zero-version.yml`](../../.github/workflows/pipelinetemplates-bump-zero-versions.yml) pipeline is responsible for finding any versioned component that made it to the `main` branch, but is still at version `0.0.0`. It works by calling the [`reconcile-zero-versions.sh` script](../../shared/scripts/bash/versioning/reconcile-zero-versions.sh) to search the repository for any `VERSION` file that is still at `0.0.0`. The script bumps those versions to `0.0.1` and the pipeline commits them to a branch named `chore/reconcile-zero-versions`, and opens a PR to the `main` branch.

Each time the pipeline runs, it hard resets the `chore/reconcile-zero-versions` to the `main` branch, then runs the version bumps. This ensures that any component versioned `0.0.0` in the main branch will bump to `0.0.1`, even modules from previous runs. The PR will always have the latest changes, and can be merged at any point.

### Pipeline: Github PR pipeline

Each time a pull request (PR) to `main` is opened, the [`pipelinetemplates-pr.yml` pipeline](../../.github/workflows/pipelinetemplates-pr.yml) template runs. The pipeline installs `bump-my-version`, then runs through the follow steps:

- Finds all components that have a `VERSION` file (Github Actions, Gitlab Components, etc).
- Bumps the `VERSION` file using commit history for bump level
  - `breaking!()` changes create a major bump (`X.0.0`)
  - `feat()` changes create a minor bump (`0.X.0`)
  - `fix()` changes create a patch bump (`0.0.X`)
- Commits any changed components back to the PR branch

When a PR is left open and more changes are added, the steps will repeat, but the version will not bump more than once per PR. For example, if you bump a version from `0.0.1` to `0.0.2` when the PR is opened, then you push more changes and the pipeline runs again, the script will detect the existing bump and will not bump it again.

### Pipeline: Merge and release pipeline

The [`pipelinetemplates-merge-release.yml` pipeline](../../.github/workflows/pipelinetemplates-merge-release.yml) once a PR is merged into the `main` branch. The pipeline finds any changed components/`VERSION` files, then it ensures all of those tags are created.

Read more about how pipeline versioning works in the [`VERSIONING` docs](../versioning/README.md).

### Pipeline: Git tag reconciliation pipeline

The [`pipelinetemplates-git-tag.yml` pipeline](../../.github/workflows/pipelinetemplates-git-tag.yml) runs on a schedule or on-demand, ensuring a tag exists for each component.

The pipeline calls the [`git-tag-components.sh` script](../../shared/scripts/bash/versioning/git-tag-components.sh) to find all versioned components, then compares the versions with published tags. If any `VERSION` file is found to have a version that does not exist as a git tag, the pipeline creates that tag.
