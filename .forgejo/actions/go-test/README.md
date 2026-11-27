# Forgejo Action: Go test

This action runs `go test` against a Go module. It supports the race detector, coverage collection with an optional minimum threshold, build tags, and extra `go test` arguments. It writes a job summary, saves the test log and coverage reports to an output directory, and can upload that directory as an artifact for CI use.

This action does not install Go. Run the `setup-go` action (or any step that puts `go` on `PATH`) before it.

## Inputs

- `module-dir`: Path to the Go module root (where `go.mod` lives). Default: `"."`.
  - `"."` when the Go module is at the repo root
  - `"apps/api"` for a monorepo app under `apps/api`
- `packages`: Space-separated package patterns to test, relative to `module-dir`. Default: `"./..."`.
  - `"./..."` to test every package in the module
  - `"./internal/... ./pkg/..."` to test only some directories
  - `"./cmd/cli"` to test a single package
- `race`: `"true"` to enable the race detector (`-race`). Requires cgo and a C compiler on the runner. Default: `"false"`.
- `short`: `"true"` to pass `-short`, so tests that honor `testing.Short()` skip slow work. Default: `"false"`.
- `verbose`: `"true"` to pass `-v` and print every test as it runs. Default: `"false"`.
- `count`: Value for `-count`. `"1"` bypasses Go's test result cache so tests always run. Set to an empty string to use the default caching behavior. Default: `"1"`.
- `shuffle`: `"true"` to pass `-shuffle=on` and randomize test order, which helps expose order-dependent tests. Default: `"false"`.
- `timeout`: Value for `-timeout`. Default: `"10m"`.
  - `"30s"` for a fast unit test suite
  - `"1h"` for slow integration tests
- `build-tags`: Comma-separated build tags passed to `-tags`. Default: empty string.
  - `integration` to include tests behind an `integration` build tag
  - `integration,postgres` for multiple tags
- `coverage`: `"true"` to collect coverage (`-coverprofile` with `-covermode=atomic`) and generate coverage reports. Default: `"false"`.
- `coverage-threshold`: Minimum total coverage, as a percent. The step fails if total coverage is lower. Setting this automatically enables `coverage`. Default: empty string (no threshold).
  - `"60"` to require at least 60% coverage
  - `"82.5"` decimals are allowed
- `extra-args`: Additional arguments appended to the `go test` command, space-separated. Default: empty string.
  - `-failfast` to stop after the first failing test
  - `-run=TestAPI` to run only tests matching a pattern
  - `-parallel=2` to limit test parallelism on busy runners
- `output-dir`: Directory, relative to `module-dir`, where the test log and coverage files are written. Default: `"test-results"`.
- `upload-artifacts`: `"true"` to upload the output directory as an artifact. The upload runs even when tests fail, so the log is available for debugging. Default: `"false"`.
- `artifact-name`: Name for the uploaded artifact. Names must be unique within a workflow run, so use different names if the action runs more than once in the same run. Default: `"go-test-results"`.

## Outputs

- `result`: `passed` or `failed`.
- `coverage`: Total coverage as reported by Go, such as `72.4%`. Empty when coverage is not collected.

## Files written

All files are written to `output-dir` (default `test-results/`, inside `module-dir`):

- `go-test.log`: Full `go test` output.
- `coverage.out`: Raw coverage profile (when coverage is enabled).
- `coverage.txt`: Per-function coverage report from `go tool cover -func`, ending with the total.
- `coverage.html`: Browsable HTML coverage report.

Add `test-results/` to your repository's `.gitignore` so these files are never committed.

## Behavior

- The step fails when any test fails, a package fails to build, the timeout is hit, or coverage is below `coverage-threshold`.
- Coverage is only checked against the threshold when the tests themselves pass.
- A job summary is written with the result, package counts, coverage, the exact `go test` command, and up to 50 failed test names. Forgejo displays job summaries on v17 or newer with Forgejo Runner 13.2 or newer. On older versions the summary is simply not shown.

## Usage

- Run all tests with the race detector and coverage:

  ```yaml
  ---
  name: Go Tests

  on:
    pull_request:

  jobs:
    test:
      runs-on: docker
      steps:
        - name: Checkout
          uses: https://github.com/actions/checkout@v7

        - name: Setup Go
          uses: redjax/PipelineTemplates/.forgejo/actions/setup-go@branch-tag-or-ref
          with:
            version: "1.27.4"
            enable-cache: "true"

        - name: Run tests
          uses: redjax/PipelineTemplates/.forgejo/actions/go-test@branch-tag-or-ref
          with:
            module-dir: "."
            packages: "./..."
            race: "true"
            short: "false"
            verbose: "false"
            count: "1"
            shuffle: "false"
            timeout: "10m"
            build-tags: ""
            coverage: "true"
            coverage-threshold: ""
            extra-args: ""
            output-dir: "test-results"
            upload-artifacts: "true"
            artifact-name: "go-test-results"
  ```

- Enforce a minimum coverage and use the result in a later step:

  ```yaml
  ---
  name: Go Tests With Coverage Gate

  on:
    pull_request:

  jobs:
    test:
      runs-on: docker
      steps:
        - name: Checkout
          uses: https://github.com/actions/checkout@v7

        - name: Setup Go
          uses: redjax/PipelineTemplates/.forgejo/actions/setup-go@branch-tag-or-ref
          with:
            version: "1.27.4"
            enable-cache: "true"

        - name: Run tests
          id: test
          uses: redjax/PipelineTemplates/.forgejo/actions/go-test@branch-tag-or-ref
          with:
            coverage-threshold: "60"
            upload-artifacts: "true"

        - name: Show coverage
          if: always()
          shell: bash
          run: |
            echo "Result: ${{ steps.test.outputs.result }}"
            echo "Coverage: ${{ steps.test.outputs.coverage }}"
  ```

- Run integration tests in a monorepo module:

  ```yaml
  ---
  name: Integration Tests

  on:
    workflow_dispatch:

  jobs:
    integration:
      runs-on: docker
      steps:
        - name: Checkout
          uses: https://github.com/actions/checkout@v7

        - name: Setup Go
          uses: redjax/PipelineTemplates/.forgejo/actions/setup-go@branch-tag-or-ref
          with:
            version: "1.27.4"
            enable-cache: "true"

        - name: Run integration tests
          uses: redjax/PipelineTemplates/.forgejo/actions/go-test@branch-tag-or-ref
          with:
            module-dir: "apps/api"
            packages: "./internal/..."
            build-tags: "integration"
            timeout: "30m"
            extra-args: "-failfast"
            artifact-name: "api-integration-test-results"
            upload-artifacts: "true"
  ```

To run tests as part of a pull request check, or as a standalone reusable workflow, see the `go-pr-checks` and `go-test` workflows.
