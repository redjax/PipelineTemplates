# Forgejo Action: Bump version

This action updates a repository version using [`bump-my-version`](https://github.com/callowayproject/bump-my-version). It can use an explicitly selected bump type or automatically determine a semantic version bump from Git commit history.

The action modifies the configured version file in the current working tree. It does not commit changes, create branches, open pull requests, create tags, or publish releases.

## Inputs

- `bump-type`: Version bump type. Valid values: `auto`, `major`, `minor`, or `patch`. Default: `"auto"`.
  - `auto` detects the bump type from commit subjects since the latest Git tag.
  - `major` is selected automatically when commits contain a breaking-change marker.
  - `minor` is selected automatically when a commit subject starts with `feat:`, or `feat(scope):`.
  - `patch` is selected automatically when no major or minor condition matches.
- `version-file`: Path to the version file relative to the repository root. Default: `".version"`.
  - `.version` for a repository-specific version file.
  - `VERSION` for projects following common release-file conventions.
  - `deploy/version.txt` for applications that keep deployment metadata under `deploy/`.
- `bumpversion-config`: Path to the bump-my-version configuration file. Default: `".bumpversion.toml"`.
  - `.bumpversion.toml` for TOML-based bump-my-version configuration.
  - `pyproject.toml` when bump-my-version configuration is stored with other project metadata.
  - `deploy/.bumpversion.toml` for a configuration file located below a deployment directory.

## Outputs

- `current-version`: Version value before bump-my-version modifies the version file.
- `new-version`: Version value after bump-my-version completes.
- `bump-type`: Resolved bump type used for this run.
- `version-file`: Version file modified by the action.

## Usage

- Automatically select a version bump from conventional commit history:

  ```yaml
  ---
  name: Bump Version

  on:
    workflow_dispatch:

  jobs:
    bump:
      runs-on: forgejo-runner-base
      steps:
        - name: Checkout
          uses: https://github.com/actions/checkout@v7
          with:
            fetch-depth: 0

        - name: Bump version
          id: version
          uses: redjax/PipelineTemplates/.forgejo/actions/bump-version@main
          with:
            bump-type: auto
            version-file: ".version"
            bumpversion-config: ".bumpversion.toml"

        - name: Print version change
          shell: bash
          run: |
            echo "Previous version: ${{ steps.version.outputs.current-version }}"
            echo "New version: ${{ steps.version.outputs.new-version }}"
            echo "Bump type: ${{ steps.version.outputs.bump-type }}"
  ```

- Explicitly create a patch version bump:

  ```yaml
  - name: Bump patch version
    id: version
    uses: ./pipelinetemplates/.forgejo/actions/bump-version
    with:
      bump-type: patch
      version-file: ".version"
      bumpversion-config: ".bumpversion.toml"
  ```

The checkout should use `fetch-depth: 0` when `bump-type: auto` is used. The action needs Git tags and commit history to determine the previous release boundary and inspect commit messages.
