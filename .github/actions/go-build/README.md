# Github Action: Go build

This Action builds Go applications and optionally uploads cross‑compiled binaries as artifacts. It is designed to work for both flat layouts (`main.go` at the repo root) and monorepo layouts (apps in subdirs, i.e. `apps/go-service/cmd/service/main.go`).

## Inputs

- `module-dir`: Path to the directory containing `go.mod` and the entrypoint package (default: `.`).
  - `.` (Go module at repo root)
  - `apps/api` (app is in `apps/api/go.mod`)
  - `services/auth-service`
- `build-package`: Go package path to build, for example `.` or `./cmd/example`. Required.
  - `.` (main package is at the module root, i.e. `main.go`)
  - `./cmd/server` (typical `cmd/server/main` entrypoint)
  - `./cmd/migrate` (separate CLI for running migrations)
- `binary-name`: Name to give the built binary file. Required.
  - `api`
  - `auth-service`
  - `migrate`
  - `some-bin-name`
- `platforms`: Comma‑separated list of `GOOS/GOARCH` targets, such as `linux/amd64,linux/arm64`. Default: `linux/amd64`.
  - `linux/amd64`
  - `linux/arm64`
  - `linux/amd64,linux/arm64`
  - `linux/amd64,linux/arm64,windows/amd64`
- `build-tags`: Optional list of Go build tags passed to go build `-tags`. Default: empty.
  - `debug` (build with `//go:build debug` sections enabled)
  - `prod` (build with production-only code paths)
  - `debug integration` (Pass and enable multiple tags as a space-separated list)
- `ldflags`: Optional flags passed to go build `-ldflags`. Often used to inject version info, for example `-X main.version=${{ github.sha }}`. Default: empty.
  - `-X main.version=${{ github.sha }}` (pass the Github commit SHA as the version)
  - `-X main.version=${{ github.sha }} -X main.commit=${{ github.sha }} -X main.buildDate=${{ date -u +%Y-%m-%d%T%H%M:%SZ }}` (multiple flags, including a build date)
  - Use `-s -w` to strip debug info:
    - `-s -w -X main.version=${{ github.ref_name }} -X main.commit=${{ github.sha }}`
- `output-dir`: Directory under module-dir where build artifacts are written. Default: `dist`.
  - `dist`
  - `build`
  - `out/linux`
- `go-version`: Go toolchain version to install with `actions/setup-go`. Default: `1.25.6`.
  - A valid [Go release version](https://go.dev/dl/)
  - See the latest version at [https://go.dev/VERSION?m=text](https://go.dev/VERSION?m=text)
- `artifact-name`: Optional name for the uploaded artifact. If not set, the name defaults to `<repo-name>-<binary-name>-dist`.
  - `api-dist`
  - `auth-service-linux`
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
      runs-on: ubuntu-latest
      steps:
      - name: Checkout
        uses: actions/checkout@v6

      - name: Build Go app
        uses: redjax/PipelineTemplates/.github/actions/go-build@gh/go-build/v0.0.1
        with:
        module-dir: .
        build-package: .
        go-version: "1.25.6"
        binary-name: example
        platforms: linux/amd64,linux/arm64
        upload-artifacts: "true"
        artifact-name: example-dist
        ldflags: -X main.version=${{ github.sha }}
  ```

- Monorepo, module under `apps/go-example` with entrypoint in `cmd/example/main.go`:

  ```yaml
  ---
  name: Build Go (monorepo)

  on:
    workflow_dispatch:

  jobs:
    build:
      runs-on: ubuntu-latest
      steps:
        - name: Checkout
          uses: actions/checkout@v6

        - name: Build Go app from apps/go-example
          uses: redjax/PipelineTemplates/.github/actions/go-build@gh/go-build/v0.0.1
          with:
            module-dir: apps/go-example
            build-package: ./cmd/example
            go-version: "1.25.6"
            binary-name: ex
            platforms: linux/amd64,linux/arm64
            upload-artifacts: "true"
            artifact-name: example-dist
            ldflags: -X main.version=${{ github.sha }}
  ```
