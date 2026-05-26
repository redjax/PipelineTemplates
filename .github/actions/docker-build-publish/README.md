# Github Action: Docker build & Publish

This Action builds Docker images with `docker/build-push-action` and optionally pushes them to a container registry. It wraps checkout, Buildx setup, registry login, and build-push in a single reusable step for common CI/CD Docker workflows.

## Inputs

- `context`: Build context path passed to Docker.
  - `.` (build from repo root)
  - `./apps/api` (monorepo app under apps/api)
- `dockerfile`: Path to the Dockerfile, relative to context.
  - `Dockerfile` (Dockerfile at root of repository)
  - `build/api.Dockerfile` (Dockerfile nested in subdirectory)
- `image_name`: Image repository name, without the registry host.
  - `my-org/my-app`
  - `my-user/tooling`
- `tags`: Newline‑separated list of tags to apply to the image. These are typically just the tag parts (for example latest, `v1.2.3`); the action composes full references as `<registry>/<image_name>:<tag>`.
  - `latest` (single, 'latest' tag)
  - `sha-${{ github.sha }}` (commit-based tag)
  - `branch-${{ github.ref_name }}` (branch-based tag)
  - `v1.2.3` (versioned release tag)
  - Multiple tags:

    ```plaintext
    latest
    branch-${{ github.ref_name }}
    sha-${{ github.sha }}
    v1.2.3
    ```

- `push`: `"true"` to push the built image(s) to the registry, `"false"` to build only. Default: `"true"`.
- `platforms`: Comma‑separated list of target platforms for multi‑arch builds. Default: `linux/amd64`.
  - `linux/amd64`
  - `linux/amd64,linux/arm64`
- `build_args`: Build arguments passed to Docker, as newline‑separated KEY=VALUE pairs. Default: empty.
  
  ```plaintext
  GIT_SHA=${{ github.sha }}
  GIT_SHA=${{ github.sha }}
  BUILD_DATE=${{ github.run_id }}
  ```

- `cache_from`: Cache sources for Docker builds (cache-from in `docker/build-push-action`). Default: empty.
  - `type=registry,ref=ghcr.io/my-org/my-app:cache`
- `cache_to`: Cache destinations for Docker builds (`cache-to` in `docker/build-push-action`). Default: empty.
  - `type=registry,ref=ghcr.io/my-org/my-app:cache,mode=max`
- `registry`: Registry hostname.
  - `ghcr.io`
  - `docker.io`
- `registry_username`: Username for logging into the registry.
  - `${{ github.actor }}` for GHCR
  - A service account user for Docker Hub
- `registry_password`: Password or token for registry login.
  - `${{ secrets.GITHUB_TOKEN }}` for GHCR
  - `${{ secrets.DOCKERHUB_TOKEN }}` for Docker Hub

## Usage

- Simple single-tag push to Github container registry:

  ```yaml
  ---
  name: Build and publish Docker image

  on:
    push:
      branches:
        - main

  jobs:
    docker:
      runs-on: ubuntu-latest
      steps:
        - name: Build and publish
          uses: redjax/PipelineTemplates/.github/actions/docker-build-publish@gh/docker-build-publish/v0.0.1
          with:
            context: .
            dockerfile: ./Dockerfile
            image_name: my-org/my-app
            tags: |
              latest
            push: "true"
            platforms: linux/amd64,linux/arm64
            build_args: |
              GIT_SHA=${{ github.sha }}
              BUILD_DATE=${{ github.run_id }}
            cache_from: ""
            cache_to: ""
            registry: ghcr.io
            registry_username: ${{ github.actor }}
            registry_password: ${{ secrets.GITHUB_TOKEN }}
  ```

- Multi‑tag example (same commit tagged multiple ways):

  ```yaml
        - name: Build and publish multi-tag
          uses: redjax/PipelineTemplates/.github/actions/docker-build-publish@gh/docker-build-publish/v0.0.1
          with:
            context: .
            dockerfile: ./Dockerfile
            image_name: my-org/my-app
            tags: |
              latest
              sha-${{ github.sha }}
              ${{
                github.ref_type == 'tag' && github.ref_name || 'branch-' + github.ref_name
              }}
            push: "true"
            platforms: linux/amd64
            build_args: ""
            cache_from: ""
            cache_to: ""
            registry: ghcr.io
            registry_username: ${{ github.actor }}
            registry_password: ${{ secrets.GITHUB_TOKEN }}
  ```
