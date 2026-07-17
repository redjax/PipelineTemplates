# Hugo Publish to GitHub Pages <!-- omit in toc -->

The [`hugo-publish-gh-pages`](../../../../../.github/workflows/hugo-publish-gh-pages.yml) workflow publishes a built Hugo site artifact to GitHub Pages. It is destination-specific and contains only the inputs and deploy steps needed for the GitHub Pages publishing flow.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)

## Responsibilities

- Download the Hugo build artifact from the upstream build run.
- Configure the GitHub Pages environment.
- Upload the artifact as a Pages artifact.
- Trigger the official GitHub Pages deployment.

## Inputs

- `artifact-name`: Name of the build artifact to download.
- `run-id`: Build workflow run ID to download the artifact from.
- `runner-image`: Runner label or image to use.
