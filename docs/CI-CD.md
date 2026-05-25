# CI/CD Pipelines

Depending on which platform (Github, Gitlab, etc) this repository is hosted on, there are a number of "meta" pipelines to manage things like version bumps, git tag releases, etc.

## Github Pipelines

Any pipelines that begin with `pipelinetemplates-*.yml` in the [`.github/workflows/` directory](../.github/workflows/) are automations that run for this specific repository. They are not meant to be imported/used in other repositories, they are meant to manage the `PipelineTemplates` repository itself.

### Github: Bump zero-versioned components

The [`pipelinetemplates-bump-zero-version.yml`](../.github/workflows/pipelinetemplates-bump-zero-versions.yml) pipeline is responsible for finding any versioned component that made it to the `main` branch, but is still at version `0.0.0`. It works by calling the [`reconcile-zero-versions.sh` script](../shared/scripts/bash/versioning/reconcile-zero-versions.sh) to search the repository for any `VERSION` file that is still at `0.0.0`. The script bumps those versions to `0.0.1` and the pipeline commits them to a branch named `chore/reconcile-zero-versions`, and opens a PR to the `main` branch.

Each time the pipeline runs, it hard resets the `chore/reconcile-zero-versions` to the `main` branch, then runs the version bumps. This ensures that any component versioned `0.0.0` in the main branch will bump to `0.0.1`, even modules from previous runs. The PR will always have the latest changes, and can be merged at any point.

> [!NOTE]
> As of 2026-05-25, the PR this pipeline creates will stay open until it is manually merged. This is because some of the branch protection rules run for an unpredictable amount of time, causing the version reconciliation pipelines to fail, and I have not spent the time to figure that out.

### Github: PR pipeline

Each time a pull request (PR) to `main` is opened, the [`pipelinetemplates-pr.yml` pipeline](../.github/workflows/pipelinetemplates-pr.yml) template runs. The pipeline installs `bump-my-version`, then runs through the follow steps:

- Finds all components that have a `VERSION` file (Github Actions, Gitlab Components, etc).
- Bumps the `VERSION` file using commit history for bump level
  - `breaking!()` changes create a major bump (`X.0.0`)
  - `feat()` changes create a minor bump (`0.X.0`)
  - `fix()` changes create a patch bump (`0.0.X`)
- Commits any changed components back to the PR branch

When a PR is left open and more changes are added, the steps will repeat, but the version will not bump more than once per PR. For example, if you bump a version from `0.0.1` to `0.0.2` when the PR is opened, then you push more changes and the pipeline runs again, the script will detect the existing bump and will not bump it again.

### Github: Merge and release pipeline

The [`pipelinetemplates-merge-release.yml` pipeline](../.github/workflows/pipelinetemplates-merge-release.yml) once a PR is merged into the `main` branch. The pipeline finds any changed components/`VERSION` files, then it ensures all of those tags are created.

Read more about how pipeline versioning works in the [`VERSIONING` docs](./VERSIONING.md).
