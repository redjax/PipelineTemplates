# Hugo Publish to Branch <!-- omit in toc -->

The `hugo-publish-branch` workflow publishes a built Hugo site artifact to a git branch in the repository, such as `gh-pages`. It is destination-specific and contains only the inputs and git-push logic needed for branch publishing.

Some remote targets like Github Pages and Cloudflare Pages can automatically detect changes to a specific branch and publish them.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)

## Responsibilities

- Download the Hugo build artifact from the upstream build run.
- Initialize a git repository in the artifact directory.
- Force-push the site contents to the target branch.

## Inputs

- `artifact-name`: Name of the build artifact to download.
- `run-id`: Build workflow run ID to download the artifact from.
- `branch-name`: Target branch to publish to, e.g. `gh-pages`.
- `runner-image`: Runner label or image to use.
