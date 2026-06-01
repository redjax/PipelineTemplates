# Github Action: Clean GitHub Tags & Releases

This Action cleans up old Git tags and GitHub Releases from a repository. It supports two cleanup modes: keep only the latest `N` releases, or delete releases older than a given date. It also supports optional regex filtering for tag names and dry-run mode for safe previewing.

## Requirements

- `gh` CLI (installed by the action)
- `jq` (installed by the action)
- Authenticated GitHub session (`GH_TOKEN` from `github.token`)
- Workflow permission `contents: write` to delete releases and tags

## Inputs

- `mode`: Cleanup mode (required).
  - `keep-latest`: Keep only the latest `N` releases.
  - `older-than`: Delete releases older than a given date.

- `keep_latest`: Number of newest releases to keep (used with `mode=keep-latest`). Default: `"10"`.
  - `"10"` (keep the 10 most recent releases)
  - `"5"` (keep only the 5 most recent releases)

- `older_than`: Delete releases older than this date (used with `mode=older-than`). Format: `YYYY-MM-DD`.
  - `"2025-01-01"` (delete releases older than Jan 1, 2025)
  - `"2024-06-01"` (delete releases older than Jun 1, 2024)

- `tag_pattern`: Regex pattern for tag names to consider (optional). If empty, all tags are considered.
  - `^v[0-9]+` (only tags starting with `v` followed by digits)
  - `^v[0-9]+\.[0-9]+\.[0-9]+$` (only semver tags like `v1.2.3`)
  - `^release-` (only tags starting with `release-`)
  - `^pkg-[a-z]+-` (only tags matching a package naming scheme)

- `dry_run`: Preview deletions only without actually deleting. Default: `"true"`.
  - `"true"` (show what would be deleted)
  - `"false"` (actually delete releases and tags)

- `repo`: Target repository as `OWNER/REPO` (optional). Default: current repository.
  - `"redjax/my-app"` (target a specific repo)
  - `"my-org/pipelinetemplates"` (target an org repo)

## Usage

- Keep the latest 10 releases (dry-run preview):

  ```yaml
  ---
  name: Clean old GitHub tags

  on:
    workflow_dispatch:
      inputs:
        mode:
          description: Cleanup mode
          required: true
          type: choice
          options:
            - keep-latest
            - older-than
        keep_latest:
          description: Number of newest releases to keep
          required: false
          default: "10"
        dry_run:
          description: Preview deletions only
          required: false
          default: true
          type: boolean

  jobs:
    clean-tags:
      runs-on: ubuntu-latest
      permissions:
        contents: write
      steps:
        - uses: actions/checkout@v6
          with:
            fetch-depth: 0

        - name: Clean old releases (keep latest 10)
          uses: redjax/PipelineTemplates/.github/actions/clean-tags-releases@gh/tag-cleanup/v0.1.0
          with:
            mode: keep-latest
            keep_latest: 10
            dry_run: true
  ```

- Delete releases older than a date (dry-run preview):

  ```yaml
  jobs:
    clean-tags:
      runs-on: ubuntu-latest
      permissions:
        contents: write
      steps:
        - uses: actions/checkout@v6
          with:
            fetch-depth: 0

        - name: Clean releases older than 2025-01-01
          uses: redjax/PipelineTemplates/.github/actions/clean-tags-releases@gh/tag-cleanup/v0.1.0
          with:
            mode: older-than
            older_than: 2025-01-01
            dry_run: true
  ```

- Clean only semver-tagged releases (actual deletion):

  ```yaml
  jobs:
    clean-tags:
      runs-on: ubuntu-latest
      permissions:
        contents: write
      steps:
        - uses: actions/checkout@v6
          with:
            fetch-depth: 0

        - name: Clean old semver releases
          uses: redjax/PipelineTemplates/.github/actions/clean-tags-releases@gh/tag-cleanup/v0.1.0
          with:
            mode: keep-latest
            keep_latest: 5
            tag_pattern: '^v[0-9]+\.[0-9]+\.[0-9]+$'
            dry_run: false
  ```

- Target a different repository:

  ```yaml
  jobs:
    clean-tags:
      runs-on: ubuntu-latest
      permissions:
        contents: write
      steps:
        - uses: actions/checkout@v6
          with:
            fetch-depth: 0

        - name: Clean tags in another repo
          uses: redjax/PipelineTemplates/.github/actions/clean-tags-releases@gh/tag-cleanup/v0.1.0
          with:
            mode: keep-latest
            keep_latest: 10
            repo: redjax/pipelinetemplates
            dry_run: true
  ```

## Notes

- **Always test with `dry_run: true` first** to see what would be deleted.
- `fetch-depth: 0` is required in the `actions/checkout` step to access all tags for deletion.
- Tags are deleted from both GitHub Releases and Git (via `git push origin ":refs/tags/<tag>"`).
- The action respects your tag naming scheme via `tag_pattern` regex filtering.
