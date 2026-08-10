# Forgejo Action: Detect Go changes

This action checks whether Go-related application files changed between two commits. It is intended for use as a lightweight gate before Go builds, version bumps, release pipelines, or other Go-specific CI work.

The action returns whether relevant files changed and provides the matching changed-file list as an output.

## Inputs

- `base-sha`: Base commit SHA used as the start of the comparison range.
  - Typically `${{ github.event.before }}` for push workflows.
  - Typically `${{ github.event.pull_request.base.sha }}` for pull request workflows.
  - When empty or an all-zero SHA, the action falls back to the previous commit or repository root commit.
- `head-sha`: Head commit SHA used as the end of the comparison range.
  - Typically `${{ github.sha }}` for push workflows.
  - Typically `${{ github.event.pull_request.head.sha }}` for pull request workflows.
- `paths`: Space-separated repository paths to inspect for Go-related changes. Default: `"go.mod go.sum cmd internal"`.
  - `"go.mod go.sum cmd internal pkg"` for a typical Go API or service.
  - `"go.mod go.sum cmd internal pkg api"` when generated API source should trigger builds.
  - `"go.mod go.sum apps/api"` for a monorepo application under `apps/api`.

## Outputs

- `changed`: `"true"` when matching Go-related files changed between `base-sha` and `head-sha`; otherwise `"false"`.
- `files`: Newline-separated list of matching changed files.

## Usage

- Detect Go changes in a push workflow:

  ```yaml
  ---
  name: Detect Go Changes

  on:
    push:
      branches:
        - main

  jobs:
    detect:
      runs-on: forgejo-runner-base
      steps:
        - name: Checkout
          uses: https://github.com/actions/checkout@v7
          with:
            fetch-depth: 0

        - name: Detect Go changes
          id: go
          uses: redjax/PipelineTemplates/.forgejo/actions/detect-go-changes@main
          with:
            base-sha: ${{ github.event.before }}
            head-sha: ${{ github.sha }}
            paths: "go.mod go.sum cmd internal pkg"

        - name: Print result
          shell: bash
          run: |
            echo "Go changes detected: ${{ steps.go.outputs.changed }}"
            echo "Changed files:"
            printf '%s\n' "${{ steps.go.outputs.files }}"
  ```

- Skip a build when no Go files changed:

  ```yaml
  - name: Build Go application
    if: steps.go.outputs.changed == 'true'
    uses: ./pipelinetemplates/.forgejo/actions/go-build
    with:
      module-dir: "."
      build-package: "./cmd/api"
      binary-name: example-api
      platforms: linux/amd64
      output-dir: dist
      upload-artifacts: "false"
  ```
