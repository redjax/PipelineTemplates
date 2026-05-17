# PipelineTemplates - Development <!-- omit in toc -->

Development documentation for the `PipelineTemplates` repository.
TODO:

- [x] Create `docs/development/` dir
  - [x] Create top level `README.md` for introduction/ToC
  - [x] Create `GITHUB.md` for Github pipeline development docs
  - [x] Create `GITLAB.md` for Gitlab pipeline development docs
  - [ ] Create `CONCOURSE.md` for Concourse CI pipeline development docs
  - [ ] Create `WOODPECKER.md` for Woodpecker CI pipeline development docs
  - [ ] Create `DAGGER.md` for Dagger pipeline development docs

## Sections

- [Github](./GITHUB.md): Documentation for Github Actions/Workflows
- [Gitlab](./GITLAB.md): Documentation for Gitlab CI
- [Testing](./TESTING.md): Documentation for testing pipelines during development, i.e. calling from another repository

## Overview

Pipelines created in this repository can be called/imported from other repositories to reduce code repetition and standardize processes. The [`manifests/version.yml` file](../../manifests/versions.yml) tracks each pipeline's current version.

> [!NOTE]
> Each time you create a new template, i.e. a new file in `.github/workflows` or `gitlab/**`, you must add the initial tag to the `manifests/version.yml` file. The tag can be derived from the path:
>
> ```plaintext
> .github/workflows/demo-hello.yml -> github/demo-hello: v0.0.1
> gitlab/demo/hello.yml -> gitlab/demo/hello: v0.0.1
> ```

When the PipelineTemplates repository is hosted on Github, the [`pipelinetemplates-pullrequest.yml` pipeline](../.github/workflows/pipelinetemplates-pullrequest.yml) runs each time a PR to `main` is opened. It detects changes to individual pipeline files in any (known) path (`.github/workflows/`, `gitlab/**/`, etc), runs the [`release.sh` script](../.scripts/release.sh) which finds all changed pipeline files in the current PR, and bumps the version for changed files in the [`manifests/versions.yml` file](../manifests/versions.yml).

You can also manually bump a specific file's version tag using the [`manual-release.sh` script](../.scripts/manual-release.sh). You must manually push tags created by this script (`git push origin <tag_name>`).
