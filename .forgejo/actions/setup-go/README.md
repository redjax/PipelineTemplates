# Forgejo Action: Setup Go

This action installs and configures a Go toolchain for Forgejo Actions runners without requiring root privileges. It downloads Go directly from the official Go distribution site, caches downloaded toolchains per version, and configures Go environment variables for subsequent pipeline steps.

This action is designed for self-hosted Forgejo runners where `actions/setup-go` may not work correctly because hosted tool cache paths are unavailable or runners execute as non-root users.

## Inputs

- `version`: Go toolchain version to install. Default: `"1.25.6"`.
  - Examples:
    - `"1.25.6"` (specific pinned version)
    - `"1.24.5"` (older supported toolchain)
  - See available Go releases at [https://go.dev/dl/](https://go.dev/dl/)

- `enable-cache`: Enable Go module and build caches. Default: `"true"`.
  - When enabled:
    - `GOCACHE` is configured to `${HOME}/.cache/go/build`
    - `GOMODCACHE` is configured to `${HOME}/.cache/go/pkg/mod`
  - Disable when debugging cache-related issues or when using an external cache mechanism.

## Behavior

The action:

- Detects the runner architecture and downloads the correct Go archive.
- Stores downloaded Go archives in:
  - `${HOME}/.cache/setup-go/downloads`
- Stores installed Go toolchains in:
  - `${HOME}/.local/share/setup-go/toolchains/<version>`
- Reuses previously installed Go versions when available.
- Adds the Go binary directory to `PATH`.
- Configures:
  - `GOROOT`
  - `GOPATH`
  - `GOCACHE`
  - `GOMODCACHE`

The action does not require:

- `sudo`
- `/opt/hostedtoolcache` dir
- root permissions

This makes it suitable for custom Forgejo runner images running as non-root users.

## Usage

Install the default Go version:

```yaml
---
name: Go Build

on:
  push:

jobs:
  build:
    runs-on: forgejo-runner-base

    steps:
      - name: Checkout
        uses: https://github.com/actions/checkout@v7

      - name: Setup Go
        uses: redjax/PipelineTemplates/.forgejo/actions/setup-go@branch-tag-or-ref
        with:
          version: "1.25.6"
          enable-cache: "true"

      - name: Verify Go installation
        shell: bash
        run: |
          go version
```

Install a different Go version:

```yaml
---
name: Go Compatibility Test

on:
  workflow_dispatch:

jobs:
  test:
    runs-on: forgejo-runner-base

    steps:
      - name: Checkout
        uses: https://github.com/actions/checkout@v7

      - name: Setup Go
        uses: redjax/PipelineTemplates/.forgejo/actions/setup-go@branch-tag-or-ref
        with:
          version: "1.24.5"
          enable-cache: "true"

      - name: Run tests
        shell: bash
        run: |
          go test ./...
```

Disable Go caching:

```yaml
---
name: Go Build Without Cache

on:
  workflow_dispatch:

jobs:
  build:
    runs-on: forgejo-runner-base

    steps:
      - name: Checkout
        uses: https://github.com/actions/checkout@v7

      - name: Setup Go
        uses: redjax/PipelineTemplates/.forgejo/actions/setup-go@branch-tag-or-ref
        with:
          version: "1.25.6"
          enable-cache: "false"
```
