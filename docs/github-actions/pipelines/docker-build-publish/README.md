# Docker Build & Publish

Pipeline: [`.github/workflows/docker-build-publish.yml`](../../../.github/workflows/docker-build-publish.yml)

## Examples

### Example caller pipeline

```shell
name: Build container

on:
  workflow_dispatch:
  push:
    branches: [main]

jobs:
  build:
    uses: redjax/PipelineTemplates/.github/workflows/docker-build-publish.yml@main
    with:
      context: ./services/api
      dockerfile: ./services/api/Dockerfile
      image_name: ghcr.io/redjax/api
      tags: |
        ghcr.io/redjax/api:latest
        ghcr.io/redjax/api:${{ github.sha }}
      push: true
      platforms: linux/amd64
    secrets:
      registry: ghcr.io
      registry_username: ${{ github.repository_owner }}
      registry_password: ${{ secrets.GITHUB_TOKEN }}

```
