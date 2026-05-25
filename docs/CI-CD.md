# CI/CD Pipelines

Depending on which platform (Github, Gitlab, etc) this repository is hosted on, there are a number of "meta" pipelines to manage things like version bumps, git tag releases, etc.

## Github Pipelines

Any pipelines that begin with `pipelinetemplates-*.yml` in the [`.github/workflows/` directory](../.github/workflows/) are automations that run for this specific repository. They are not meant to be imported/used in other repositories, they are meant to manage the `PipelineTemplates` repository itself.

### Bump zero-versioned components

The [`pipelinetemplates-bump-zero-version.yml`](../.github/workflows/pipelinetemplates-bump-zero-versions.yml) pipeline is responsible for finding any versioned component that made it to the `main` branch, but is still at version `0.0.0`. It works by calling the [`reconcile-zero-versions.sh` script](../shared/scripts/bash/versioning/reconcile-zero-versions.sh) to search the repository for any `VERSION` file that is still at `0.0.0`. The script bumps those versions to `0.0.1` and the pipeline commits them to a branch named `chore/reconcile-zero-versions`, and opens a PR to the `main` branch.

> [!NOTE]
> As of 2026-05-25, this PR stays open until it is manually merged. This is because some of the branch protection rules run for an unpredictable amount of time, causing the version reconciliation pipelines to fail.
