# Docker Build and Publish <!-- omit in toc -->

The [`docker-build-publish` workflow](../../../../../.github/workflows/docker-build-publish.yml) builds one Docker image and optionally publishes it to a container registry.

This workflow is intended for consuming repositories that build a single image per workflow run. It is a reusable wrapper around [`docker-build`](../docker-build/) and accepts the Docker build configuration directly from the caller.

For repositories that build multiple images in one workflow, use [`docker-build-matrix`](../docker-build-matrix/) instead.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Secrets](#secrets)
- [Example use](#example-use)
- [Manual example](#manual-example)
- [Build-only example](#build-only-example)

## Responsibilities

- Receive Docker build parameters from the consuming repository.
- Pass the Docker build parameters to [`docker-build`](../docker-build/).
- Build one Docker image.
- Optionally publish the image to a registry.
- Support single-platform and multi-platform builds.
- Support Dockerfile build targets.
- Support BuildKit cache configuration.
- Support BuildKit secrets, outputs, and annotations.
- Generate provenance and SBOM attestations for published images.

## Inputs

- `context`: Docker build context. Defaults to `.`.
- `dockerfile`: Path to the Dockerfile. Defaults to `Dockerfile`.
- `image`: Logical or fully qualified image name. This identifies the image being built by the caller.
- `tags`: Newline-delimited complete image references.
- `platforms`: Comma-separated target platforms. Defaults to `linux/amd64`.
- `build_args`: Newline-delimited Docker build arguments in `KEY=VALUE` format.
- `labels`: Newline-delimited Docker image labels in `KEY=VALUE` format.
- `target`: Optional Dockerfile build stage.
- `pull`: Whether Docker should always pull newer base images.
- `no_cache`: Whether Docker should disable the build cache.
- `cache_from`: Newline-delimited BuildKit cache sources.
- `cache_to`: Newline-delimited BuildKit cache destinations.
- `secrets`: Newline-delimited BuildKit secret specifications.
- `outputs`: Newline-delimited BuildKit output specifications.
- `annotations`: Newline-delimited OCI annotations.
- `publish`: Whether to push the image to the registry.

## Secrets

- `registry-token`: Token used to authenticate to the image registry. For GHCR, this is usually `${{ secrets.GITHUB_TOKEN }}`.

> [!WARNING]
> BuildKit secret values should not be supplied as ordinary workflow inputs. Use GitHub Actions secrets for sensitive values.

## Example use

The following example calls the workflow from a consuming repository:

```yaml
---
name: Build and Publish Docker Image

on:
  push:
    branches:
      - main
    tags:
      - "v*"

  pull_request:
  workflow_dispatch:

permissions:
  contents: read
  packages: write

jobs:
  docker:
    name: Build Docker image
    permissions:
      contents: read
      packages: write
    uses: redjax/pipelinetemplates/.github/workflows/docker-build-publish.yml@main
    with:
      context: .
      dockerfile: containers/Dockerfile
      image: ghcr.io/username/example-image
      tags: |
        ghcr.io/username/example-image:latest
        ghcr.io/username/example-image:git-${{ github.sha }}
      platforms: linux/amd64
      build_args: |
        GIT_SHA=${{ github.sha }}
        BUILD_DATE=${{ github.run_id }}
      labels: |
        org.opencontainers.image.source=[https://github.com/$](https://github.com/$){{ github.repository }}
        org.opencontainers.image.revision=${{ github.sha }}
      target: ""
      pull: true
      no_cache: false
      cache_from: type=gha,scope=example-image
      cache_to: type=gha,mode=max,scope=example-image
      secrets: ""
      outputs: ""
      annotations: ""
      publish: ${{ github.event_name != 'pull_request' }}
    secrets:
      registry-token: ${{ secrets.GITHUB_TOKEN }}
```

## Manual example

The workflow can also expose the reusable workflow through a manual dispatch workflow:

```yaml
---
name: Manual Docker Build

on:
  workflow_dispatch:
    inputs:
      context:
        description: "Docker build context"
        required: false
        type: string
        default: "."
      dockerfile:
        description: "Path to the Dockerfile"
        required: false
        type: string
        default: "Dockerfile"
      image:
        description: "Fully qualified image name"
        required: true
        type: string
      tags:
        description: "Newline-delimited complete image tags"
        required: true
        type: string
      platforms:
        description: "Comma-separated target platforms"
        required: false
        type: string
        default: "linux/amd64"
      push:
        description: "Push the image"
        required: false
        type: boolean
        default: false

permissions:
  contents: read
  packages: write

jobs:
  docker:
    uses: redjax/pipelinetemplates/.github/workflows/docker-build-publish.yml@main
    with:
      context: ${{ inputs.context }}
      dockerfile: ${{ inputs.dockerfile }}
      image: ${{ inputs.image }}
      tags: ${{ inputs.tags }}
      platforms: ${{ inputs.platforms }}
      publish: ${{ inputs.push }}
    secrets:
      registry-token: ${{ secrets.GITHUB_TOKEN }}
```

## Build-only example

Set:

```yaml
publish: false
```

The workflow still builds the image but does not log in to the registry or push the resulting image. This is useful for pull request validation and manual Dockerfile testing.
