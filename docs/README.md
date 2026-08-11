# PipelineTemplates Documentation

> [!NOTE]
> This repository is undergoing a significant refactor, and documentation may lag behind. The old `main` branch is archived in [`archive/2026-05-20`](https://github.com/redjax/PipelineTemplates/tree/archive/2026-05-20)

`PipelineTemplates` is a monorepo for my pipelines. Instead of copying and pasting the same pipelines across various projects, making small changes and manually porting them to other pipelines, it made more sense to consolidate them into components and pipelines in a central repository. This allows me keep all of my pipelines for the various platforms I've used (Github Actions, Gitlab Pipelines, Woodpecker/Drone CI, Concourse CI, etc) in 1 place and call them from whichever forge my code is hosted on.

## Pages

| Page                                              | Description                                                                                  |
| ------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| [ci-cd](./ci-cd/)                                 | Documentation about the "meta" pipelines that manage this repository and keep it up to date. |
| [ci-cd/github-actions](./ci-cd/github-actions/)   | Documentation for the Github Actions and reusable workflows in this repository.              |
| [ci-cd/forgejo-actions](./ci-cd/forgejo-actions/) | Documentation for the Forgejo Actions and reusable workflows in this repository.             |
| [development](./development/)                     | Documentation for developing & testing new pipeline components.                              |
| [versioning](./versioning/)                       | Documentation about how pipeline components are versioned in this repository.                |
