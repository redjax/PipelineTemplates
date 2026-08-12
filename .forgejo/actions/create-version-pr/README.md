# Forgejo Action: Create version bump PR

This action creates a version-bump branch, commits version-related changes, pushes the branch, and opens a Forgejo pull request against the configured base branch.

The action expects the version file to have already been updated by a previous step, typically the bump-version action. It does not calculate a version bump or build application artifacts.

## Inputs

- `version`: New version value used for the branch name, commit message, and pull request title.
  - `1.2.3` creates a branch such as `chore/bump-version-1.2.3`.
  - `2.0.0` creates a branch such as `chore/bump-version-2.0.0`.
- `version-file`: Version file path relative to the repository root. Default: `".version"`.
  - `.version` for the default version-file convention.
  - `VERSION` for repositories using a capitalized version file.
  - `deploy/version.txt` for version metadata stored outside the repository root.
- `bumpversion-config`: Optional bump-my-version configuration file to include in the commit. Default: `".bumpversion.toml"`.
  - `.bumpversion.toml` when the repository stores bump-my-version configuration at the root.
  - `pyproject.toml` when project metadata and bump-my-version configuration are shared.
  - Empty when no configuration file should be staged.
- `base-branch`: Target branch for the version-bump pull request. Default: `"main"`.
  - `main` for production release pipelines.
  - `develop` for repositories that release from a development branch.
  - `feat/app-release-pipeline` while testing a release pipeline on a feature branch.
- `branch-prefix`: Prefix used for the version-bump branch. Default: `"chore/bump-version-"`.
  - `chore/bump-version-` creates `chore/bump-version-1.2.3`.
  - `release/bump-` creates `release/bump-1.2.3`.
- `forgejo-endpoint`: Forgejo API endpoint ending in `/api/v1`.
  - `${{ github.server_url }}/api/v1` for a Forgejo Actions workflow.
  - `https://forgejo.example/api/v1` for an explicit Forgejo instance endpoint.
- `repository`: Repository in `owner/name` form.
  - `${{ github.repository }}` in a consuming repository workflow.
  - `redjax/pizerow-api` for an explicit repository reference.
- `token`: Forgejo token used for pull request API operations and Git branch push operations.
  - `${{ secrets.FJ_TOKEN }}` for a repository secret with write access.

## Outputs

- `branch`: Version-bump branch created or reused by the action.
- `pr-number`: Forgejo pull request number created or reused by the action.

## Usage

- Create a version-bump pull request after updating `.version`:

  ```yaml
  ---
  name: Version Bump PR

  on:
    workflow_dispatch:

  jobs:
    version-bump:
      runs-on: forgejo-runner-base
      steps:
        - name: Checkout
          uses: https://github.com/actions/checkout@v7
          with:
            fetch-depth: 0
            ref: main

        - name: Bump version
          id: version
          uses: redjax/PipelineTemplates/.forgejo/actions/bump-version@main
          with:
            bump-type: auto
            version-file: ".version"
            bumpversion-config: ".bumpversion.toml"

        - name: Create version bump PR
          id: pr
          uses: redjax/PipelineTemplates/.forgejo/actions/create-version-pr@main
          with:
            version: ${{ steps.version.outputs.new-version }}
            version-file: ".version"
            bumpversion-config: ".bumpversion.toml"
            base-branch: main
            branch-prefix: chore/bump-version-
            forgejo-endpoint: ${{ github.server_url }}/api/v1
            repository: ${{ github.repository }}
            token: ${{ secrets.FJ_TOKEN }}

        - name: Print pull request information
          shell: bash
          run: |
            echo "Version bump branch: ${{ steps.pr.outputs.branch }}"
            echo "Pull request: #${{ steps.pr.outputs.pr-number }}"
  ```

- Use the action from a checked-out PipelineTemplates mirror:

  ```yaml
  - name: Create version bump PR
    id: pr
    uses: ./pipelinetemplates/.forgejo/actions/create-version-pr
    with:
      version: ${{ steps.version.outputs.new-version }}
      version-file: ".version"
      bumpversion-config: ".bumpversion.toml"
      base-branch: main
      forgejo-endpoint: ${{ github.server_url }}/api/v1
      repository: ${{ github.repository }}
      token: ${{ secrets.FJ_TOKEN }}
  ```
