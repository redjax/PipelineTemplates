# Docker Build <!-- omit in toc -->

The [`docker-build` workflow](../../../../../.github/workflows/docker-build.yml) builds one Docker image using Docker Buildx.

The workflow can build a local or registry-oriented Docker image and optionally push it when `publish` is enabled. It is the lower-level single-image workflow used by [`docker-build-publish`](../docker-build-publish/).

For workflows that build multiple images, use [`docker-build-matrix`](../docker-build-matrix/) instead.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Secrets](#secrets)
- [Build behavior](#build-behavior)
- [Example use](#example-use)
- [Build target example](#build-target-example)
- [BuildKit feature examples](#buildkit-feature-examples)
  - [Disable the cache](#disable-the-cache)
  - [Always pull base images](#always-pull-base-images)
  - [Use GitHub Actions cache](#use-github-actions-cache)
  - [Use a BuildKit secret](#use-a-buildkit-secret)
  - [Use a custom output](#use-a-custom-output)
  - [Add OCI annotations](#add-oci-annotations)

## Responsibilities

- Check out the consuming repository.
- Configure QEMU.
- Configure Docker Buildx.
- Authenticate to the configured registry when publishing.
- Build one Docker image.
- Apply the caller-provided context and Dockerfile.
- Apply the caller-provided platforms, tags, labels, and build arguments.
- Configure Docker cache sources and destinations.
- Support Dockerfile build targets.
- Support BuildKit secrets, outputs, and annotations.
- Optionally push the resulting image.
- Generate provenance and SBOM attestations for published images.

## Inputs

- `context`: Docker build context. Defaults to `.`.
- `dockerfile`: Path to the Dockerfile. Defaults to `Dockerfile`.
- `tags`: Newline-delimited complete image references.
- `platforms`: Comma-separated target platforms. Defaults to `linux/amd64`.
- `build-args`: Newline-delimited Docker build arguments in `KEY=VALUE` format.
- `labels`: Newline-delimited Docker image labels in `KEY=VALUE` format.
- `target`: Optional Dockerfile build stage.
- `pull`: Whether Docker should always pull newer base images.
- `no-cache`: Whether Docker should disable the build cache.
- `cache-from`: Newline-delimited BuildKit cache sources.
- `cache-to`: Newline-delimited BuildKit cache destinations.
- `secrets`: Newline-delimited BuildKit secret specifications.
- `outputs`: Newline-delimited BuildKit output specifications.
- `annotations`: Newline-delimited OCI annotations.
- `publish`: Whether to push the image to the registry.
- `registry`: Registry hostname. Defaults to `ghcr.io`.
- `registry-username`: Registry username. Defaults to `github.actor` when empty.

## Secrets

- `registry-token`: Token used to authenticate to the configured registry. For GHCR, this is usually `${{ secrets.GITHUB_TOKEN }}`.

> [!WARNING]
> BuildKit secret specifications are supplied through the `secrets` input, but secret values should come from GitHub Actions secrets rather than being written directly into workflow files.

## Build behavior

When `publish` is `false`:

- The repository is checked out.
- Buildx is configured.
- The image is built.
- The registry is not used for authentication.
- The image is not pushed.
- Provenance and SBOM generation are disabled by the workflow.

When `publish` is `true`:

- The workflow authenticates to the configured registry.
- The image is built with registry-compatible output.
- The image is pushed.
- Provenance is generated.
- An SBOM is generated.

For multi-platform builds, use a registry push or another multi-platform-capable output. A local Docker image load is not suitable for loading multiple platforms into the local Docker image store.

## Example use

The following example calls the workflow directly:

```yaml
---
name: Build Docker Image

on:
  pull_request:
  push:
    branches:
      - main
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
    uses: redjax/pipelinetemplates/.github/workflows/docker-build.yml@main
    with:
      context: .
      dockerfile: containers/Dockerfile
      tags: |
        ghcr.io/username/example-image:latest
        ghcr.io/username/example-image:git-${{ github.sha }}
      platforms: linux/amd64
      build-args: |
        GIT_SHA=${{ github.sha }}
        BUILD_DATE=${{ github.run_id }}
      labels: |
        org.opencontainers.image.source=[https://github.com/$](https://github.com/$){{ github.repository }}
        org.opencontainers.image.revision=${{ github.sha }}
      target: ""
      pull: true
      no-cache: false
      cache-from: type=gha,scope=example-image
      cache-to: type=gha,mode=max,scope=example-image
      secrets: ""
      outputs: ""
      annotations: ""
      publish: ${{ github.event_name != 'pull_request' }}
    secrets:
      registry-token: ${{ secrets.GITHUB_TOKEN }}
```

## Build target example

A multi-stage Dockerfile can define named stages:

```dockerfile
FROM golang:1.26-alpine AS build

WORKDIR /src

COPY . .

RUN go build -o /out/example ./cmd/example

FROM alpine:3.24 AS runtime

COPY --from=build /out/example /usr/local/bin/example

ENTRYPOINT ["/usr/local/bin/example"]

FROM build AS test

RUN go test ./...
```

The caller can select a stage:

```yaml
with:
  target: test
```

If `target` is empty, Docker uses the final stage in the Dockerfile.

## BuildKit feature examples

### Disable the cache

```yaml
with:
  no-cache: true
```

### Always pull base images

```yaml
with:
  pull: true
```

### Use GitHub Actions cache

```yaml
with:
  cache-from: type=gha,scope=example-image
  cache-to: type=gha,mode=max,scope=example-image
```

### Use a BuildKit secret

The Dockerfile can consume a secret:

```dockerfile
RUN --mount=type=secret,id=private-config \
    cat /run/secrets/private-config
```

The workflow can pass a secret specification:

```yaml
with:
  secrets: |
    private-config=env:PRIVATE_CONFIG
```

The environment variable must be made available to the build job by the consuming workflow.

### Use a custom output

```yaml
with:
  outputs: |
    type=oci,dest=/tmp/example-image.tar
```

The output mode should be selected intentionally. Registry publishing, local Docker loading, OCI archives, and local filesystem outputs are different BuildKit output modes.

### Add OCI annotations

```yaml
with:
  annotations: |
    manifest:org.opencontainers.image.title=example-image
    manifest:org.opencontainers.image.description=Example Docker image
```

Annotations are especially useful for registry-published multi-platform images.
