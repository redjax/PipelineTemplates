# Docker Matrix Build <!-- omit in toc -->

The [`docker-build-matrix` workflow](../../../../../.github/workflows/docker-build-matrix.yml) builds multiple Docker images from a caller-provided matrix.

The workflow is intentionally repository-agnostic. It does not discover images, read repository-specific metadata, or determine which images changed. The consuming repository is responsible for creating the matrix and supplying all Docker build values.

Each matrix entry describes one Docker image build. The workflow creates one GitHub Actions job for each matrix entry and can optionally publish the resulting images to their configured registries.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Matrix definition](#matrix-definition)
- [Matrix fields](#matrix-fields)
- [Inputs](#inputs)
- [Secrets](#secrets)
- [Example use](#example-use)
- [Build-only example](#build-only-example)
- [Multi-platform example](#multi-platform-example)

## Responsibilities

- Check out the consuming repository.
- Create one build job for each matrix entry.
- Configure QEMU for cross-platform builds.
- Configure Docker Buildx.
- Log in to each image registry when publishing is enabled.
- Build Docker images using [`docker/build-push-action`](https://github.com/docker/build-push-action).
- Apply the caller-provided build context and Dockerfile.
- Apply the caller-provided tags, labels, and build arguments.
- Configure Docker build cache sources and destinations.
- Support optional Dockerfile targets.
- Support optional BuildKit secrets, outputs, and annotations.
- Optionally push the built images.
- Generate provenance and SBOM attestations for published images.

## Matrix definition

The `matrix` input is a JSON array. Each object in the array describes one Docker image build.

Example matrix:

```json
[
  {
    "name": "app-name",
    "context": "containers/app-name",
    "dockerfile": "containers/app-name/Dockerfile",
    "platforms": "linux/amd64",
    "registry": "ghcr.io",
    "registry_username": "",
    "tags": "ghcr.io/username/app-name:latest\nghcr.io/username/app-name:abc1234",
    "build_args": "GIT_SHA=abc1234\nBUILD_DATE=2026-01-01T00:00:00Z",
    "labels": "org.opencontainers.image.source=[https://github.com/username/repository](https://github.com/username/repository)",
    "target": "",
    "pull": true,
    "no_cache": false,
    "cache_from": "type=gha,scope=app-name",
    "cache_to": "type=gha,mode=max,scope=app-name",
    "secrets": "",
    "outputs": "",
    "annotations": "",
    "publish": true
  }
]
```

> [!NOTE]
> When boolean values are inserted into a JSON matrix from GitHub Actions expressions, the consuming workflow should use `toJSON()`:
>
> ```yaml
> "pull": ${{ toJSON(inputs.pull) }}
> "no_cache": ${{ toJSON(inputs.no_cache) }}
> "publish": ${{ toJSON(inputs.push) }}
> ```
>
> This preserves the values as JSON booleans instead of producing empty or string values. GitHub's `inputs` context preserves boolean values for typed workflow inputs.

## Matrix fields

- `name`: Name displayed for the matrix job. This should be unique for each image.
- `context`: Docker build context.
- `dockerfile`: Path to the Dockerfile.
- `platforms`: Comma-separated target platforms, such as `linux/amd64,linux/arm64`.
- `registry`: Registry hostname, such as `ghcr.io`.
- `registry_username`: Optional registry username. Defaults to `github.actor` when empty.
- `tags`: Newline-delimited complete image references.
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
- `publish`: Whether this image may be published when the workflow-level `publish` input is enabled.

## Inputs

- `matrix`: JSON array of Docker image build definitions.
- `publish`: Enables publishing for matrix entries whose `publish` field is `true`.

## Secrets

- `registry-token`: Token used to authenticate to the configured image registries. For GitHub Container Registry, this is usually `${{ secrets.GITHUB_TOKEN }}`.

> [!WARNING]
> BuildKit secret values should not be placed directly inside the matrix JSON. Use GitHub Actions secrets and pass only the required secret specification to the workflow.

## Example use

The following example calls the workflow from a consuming repository:

```yaml
---
name: Build Docker image matrix

on:
  workflow_dispatch:
    inputs:
      push:
        description: "Push images to GHCR"
        required: false
        type: boolean
        default: true
      platforms:
        description: "Comma-separated target platforms"
        required: false
        type: string
        default: "linux/amd64,linux/arm64"

permissions:
  contents: read
  packages: write

jobs:
  build-matrix:
    name: Build Docker matrix
    permissions:
      contents: read
      packages: write
    uses: redjax/pipelinetemplates/.github/workflows/docker-build-matrix.yml@main
    with:
      publish: ${{ inputs.push }}
      matrix: |
        [
          {
            "name": "app-name",
            "context": "containers/app-name",
            "dockerfile": "containers/app-name/Dockerfile",
            "platforms": "${{ inputs.platforms }}",
            "registry": "ghcr.io",
            "registry_username": "${{ github.actor }}",
            "tags": "ghcr.io/example/app-name:latest\nghcr.io/example/app-name:run-${{ github.run_id }}",
            "build_args": "GIT_SHA=${{ github.sha }}\nBUILD_DATE=${{ github.run_id }}",
            "labels": "org.opencontainers.image.source=[https://github.com/$](https://github.com/$){{ github.repository }}",
            "target": "",
            "pull": true,
            "no_cache": false,
            "cache_from": "type=gha,scope=app-name",
            "cache_to": "type=gha,mode=max,scope=app-name",
            "secrets": "",
            "outputs": "",
            "annotations": "",
            "publish": ${{ toJSON(inputs.push) }}
          }
        ]
    secrets:
      registry-token: ${{ secrets.GITHUB_TOKEN }}
```

> [!NOTE]
> The calling job must grant `packages: write` when publishing images.

## Build-only example

Set the workflow-level input to:

```yaml
publish: false
```

The matrix entries can still contain:

```json
"publish": true
```

The workflow-level value takes precedence and prevents all registry pushes. A build-only matrix job still checks out the repository, configures Buildx, and builds every matrix entry. It does not log in to the registries or push the images.

## Multi-platform example

Use a comma-separated platform list:

```json
"platforms": "linux/amd64,linux/arm64"
```

Common platform values include:

```text
linux/amd64
linux/arm64
linux/arm/v7
linux/arm/v6
linux/ppc64le
linux/s390x
linux/riscv64
```

Every base image used by the Dockerfile must support the requested platforms. For example, the `alpine` image is Linux-based, so it can only build `linux/*` architectures.

Some example strings:

- `linux/amd64`
- `linux/amd64,linux/arm64`
- `linux/amd64,linux/arm/v6,linux/arm/v7`
