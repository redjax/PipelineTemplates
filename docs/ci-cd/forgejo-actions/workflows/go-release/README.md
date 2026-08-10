# Go Release <!-- omit in toc -->

The [`go-release` workflow](../../../../../.forgejo/workflows/go-release.yml) builds and publishes a Go application release from an already-determined release version.

The workflow supports standard Go builds and [GoReleaser](https://goreleaser.com/) builds. It creates release archives, creates or reuses a Git tag, creates a Forgejo release, and uploads release assets.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Example use](#example-use)

## Responsibilities

- Check-out the consuming repository.
- Check-out PipelineTemplates at the requested revision.
- Set the release version and Git tag metadata.
- Install and configure the requested Go version.
- Build the application using go-build or GoReleaser.
- Package standard Go build output as `.tar.gz` and `.zip` archives.
- Collect GoReleaser-generated archives, checksums, and packages.
- Create a Git tag when required.
- Create or update a Forgejo release.
- Upload release assets to the Forgejo release.

## Inputs

- `release-version`: Version or commit short SHA used for release metadata and artifact names.
- `tag-prefix`: Prefix prepended to the Git tag.
- `module-dir`: Path to the Go module root.
- `build-package`: Go package to build relative to `module-dir`.
- `binary-name`: Name of the built binary.
- `go-version`: Go version to install and use.
- `platforms`: Comma-separated `GOOS/GOARCH` targets for standard Go builds.
- `build-tags`: Optional Go build tags.
- `ldflags`: Optional linker flags passed to `go build`.
- `output-dir`: Build output directory.
- `use-goreleaser`: Use GoReleaser instead of the standard go-build action.
- `goreleaser-config`: Path to the GoReleaser configuration file.
- `goreleaser-version`: GoReleaser version to install and use.
- `pipelinetemplates-ref`: PipelineTemplates revision to check out.
- `forgejo-endpoint`: Forgejo API endpoint.
- `repository`: Repository in `owner/name` form.
- `FJ_TOKEN`: Forgejo token used to create releases and upload release assets.

## Example use

This workflow can be called directly when a pipeline has already determined the release version:

```yaml
---
name: Release

on:
  push:
    tags:
      - "v*"

jobs:
  release:
    uses: redjax/PipelineTemplates/.forgejo/workflows/go-release.yml@main
    with:
      release-version: "1.2.3"
      tag-prefix: v
      module-dir: "."
      build-package: "./cmd/api"
      binary-name: pizerow-api
      go-version: "1.26.4"
      platforms: linux/amd64
      output-dir: dist
      use-goreleaser: false
      pipelinetemplates-ref: main
      forgejo-endpoint: ${{ github.server_url }}/api/v1
      repository: ${{ github.repository }}
    secrets:
      FJ_TOKEN: ${{ secrets.FJ_TOKEN }}
```

If using GoReleaser, the consuming repository should provide a `.goreleaser.yml` config file.

```yaml
---
version: 2

project_name: app-name

before:
  hooks:
    - go mod tidy

builds:
  ## Raspberry Pi Zero W (ARMv6, 32-bit)
  - id: app-name
    main: ./cmd/appname
    binary: cli-name
    env:
      - CGO_ENABLED=0
    goos:
      - linux
    goarch:
      - arm
    goarm:
      - "6"
    ldflags:
      - -s -w -X main.version={{.Version}} -X main.commit={{.Commit}} -X main.date={{.Date}}

  ## Raspberry Pi 2/3/4 (ARMv7, 32-bit)
  - id: app-name-armv7
    main: ./cmd/appname
    binary: cli-name
    env:
      - CGO_ENABLED=0
    goos:
      - linux
    goarch:
      - arm
    goarm:
      - "7"
    ldflags:
      - -s -w -X main.version={{.Version}} -X main.commit={{.Commit}} -X main.date={{.Date}}

  ## Raspberry Pi 3/4 (ARM64, 64-bit)
  - id: app-name-arm64
    main: ./cmd/appname
    binary: cli-name
    env:
      - CGO_ENABLED=0
    goos:
      - linux
    goarch:
      - arm64
    ldflags:
      - -s -w -X main.version={{.Version}} -X main.commit={{.Commit}} -X main.date={{.Date}}

  ## Linux AMD64 (x86-64)
  - id: linux-amd64
    main: ./cmd/appname
    binary: cli-name
    env:
      - CGO_ENABLED=0
    goos:
      - linux
    goarch:
      - amd64
    ldflags:
      - -s -w -X main.version={{.Version}} -X main.commit={{.Commit}} -X main.date={{.Date}}

archives:
  - formats: ["tar.gz"]
    format_overrides:
      - goos: windows
        formats: ["zip"]
    name_template: >-
      {{ .ProjectName }}_{{ .Os }}_{{ .Arch }}{{ if .Arm }}v{{ .Arm }}{{ end }}_{{ .Version }}
    files:
      - README.md

checksum:
  name_template: checksums.txt

changelog:
  sort: asc
  filters:
    exclude:
      - "^docs:"
      - "^test:"
      - "^chore:"

## Docker images for containerized deployment
# dockers:
#   - id: app-name-docker
#     use: buildx
#     goarch: arm
#     goarm: 6
#     image_templates:
#       - "app-name:{{ .Version }}-armv6"
#       - "app-name:latest-armv6"
#     build_flag_templates:
#       - "--platform=linux/arm/v6"
#       - "--label=org.opencontainers.image.title={{ .ProjectName }}"
#       - "--label=org.opencontainers.image.version={{ .Version }}"

#   - id: amd64-docker
#     use: buildx
#     goarch: amd64
#     image_templates:
#       - "app-name:{{ .Version }}-amd64"
#       - "app-name:latest-amd64"
#     build_flag_templates:
#       - "--platform=linux/amd64"
#       - "--label=org.opencontainers.image.title={{ .ProjectName }}"
#       - "--label=org.opencontainers.image.version={{ .Version }}"

```
