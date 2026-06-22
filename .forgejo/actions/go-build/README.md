# Forgejo Action: Go Build

This Action builds Go applications and optionally uploads cross‑compiled binaries as artifacts. It is designed to work for both flat layouts (`main.go` at the repo root) and monorepo layouts (apps in subdirs, i.e. `apps/go-service/cmd/service/main.go`).

## Inputs

- `module-dir`: Path to the directory containing `go.mod` and the entrypoint package (default: `.`).
- `build-package`: Go package path to build, for example `.` or `./cmd/example`. Required.
- `binary-name`: Name to give the built binary file. Required.
- `platforms`: Comma‑separated list of `GOOS/GOARCH` targets, such as `linux/amd64,linux/arm64`. Default: `linux/amd64`.
- `build-tags`: Optional list of Go build tags passed to go build `-tags`. Default: empty.
- `ldflags`: Optional flags passed to go build `-ldflags`. Often used to inject version info, for example `-X main.version=${{ forgejo.sha }}`. Default: empty.
- `output-dir`: Directory under module-dir where build artifacts are written. Default: `dist`.
- `go-version`: Go toolchain version to install with `actions/setup-go`. Default: `1.25.6`.
- `artifact-name`: Optional name for the uploaded artifact. If not set, the name defaults to `<repo-name>-<binary-name>-dist`.
- `upload-artifacts`: Whether to upload the contents of `<module-dir>/<output-dir>/` as an artifact. Default: `"true"` (string).

## Usage

- Flat repo, `main.go` at repository root:

  ```yaml
  ---
  name: Build Go (flat)

  on:
    workflow_dispatch:

  jobs:
    build:
      runs-on: docker
      steps:
        - name: Checkout
          uses: https://data.forgejo.org/actions/checkout@v6

        - name: Build Go app
          uses: redjax/PipelineTemplates/.forgejo/actions/go-build@branch-tag-or-ref
          with:
            module-dir: .
            build-package: .
            go-version: "1.25.6"
            binary-name: example
            platforms: linux/amd64,linux/arm64
            upload-artifacts: "true"
            artifact-name: example-dist
            ldflags: -X main.version=${{ forgejo.sha }}
  ```

- Monorepo, module under `apps/go-example` with entrypoint in `cmd/example/main.go`:

  ```yaml
  ---
  name: Build Go (monorepo)

  on:
    workflow_dispatch:

  jobs:
    build:
      runs-on: docker
      steps:
        - name: Checkout
          uses: https://data.forgejo.org/actions/checkout@v6

        - name: Build Go app from apps/go-example
          uses: redjax/PipelineTemplates/.forgejo/actions/go-build@branch-tag-or-ref
          with:
            module-dir: apps/go-example
            build-package: ./cmd/example
            go-version: "1.25.6"
            binary-name: ex
            platforms: linux/amd64,linux/arm64
            upload-artifacts: "true"
            artifact-name: example-dist
            ldflags: -X main.version=${{ forgejo.sha }}
  ```
