# Forgejo Action: Tag/Release

Create a git tag, Forgejo release, or both, with optional release assets and release notes. This action is useful for centralized release workflows in repos that publish build outputs from CI.

## Inputs

- `url`: Base URL of the Forgejo instance. Default: `${{ github.server_url }}`.
- `repo`: Repository in `owner/name` form. Default: `${{ github.repository }}`.
- `token`: Forgejo token with release permissions. Default: `${{ github.token }}`.
- `tag-name`: Tag to create or use, for example `v1.2.3`. Required.
- `tag-message`: Annotated tag message. Default: empty string.
- `create-tag`: `"true"` to create and push the git tag. Default: `"false"`.
- `create-release`: `"true"` to create or update the Forgejo release. Default: `"true"`.
- `release-name`: Release title. If empty, the tag name is used.
- `release-body`: Release notes text to use directly. Default: empty string.
- `release-notes-path`: Path to a file containing release notes. Default: empty string.
- `artifact-path`: Directory or file path containing release assets. Default: empty string.
- `asset-glob`: Glob pattern for release assets. Default: empty string.
- `draft`: `"true"` to create the release as a draft. Default: `"false"`.
- `prerelease`: `"true"` to mark the release as a prerelease. Default: `"false"`.
- `target-commitish`: Commit SHA or branch to attach the release to. Default: empty string.
- `overwrite-assets`: `"true"` to overwrite existing assets with the same name. Default: `"false"`.

## Outputs

- `release-url`: URL of the created or updated release.
- `release-id`: ID of the created or updated release.
- `tag-name`: Tag that was used.

## Usage

- Create a tag and a release for a versioned release:

  ```yaml
  ---
  name: Tag and Release

  on:
    push:
      tags:
        - "v*.*.*"

  jobs:
    release:
      runs-on: docker
      steps:
        - name: Create tag and release
          uses: redjax/PipelineTemplates/.forgejo/actions/tag-release@branch-tag-or-ref
          with:
            tag-name: ${{ github.ref_name }}
            tag-message: "Release ${{ github.ref_name }}"
            create-tag: "true"
            create-release: "true"
            release-name: ${{ github.ref_name }}
            release-body: "Release notes for ${{ github.ref_name }}"
            artifact-path: ./dist
            draft: "false"
            prerelease: "false"
            target-commitish: ${{ github.sha }}
            overwrite-assets: "true"
  ```

- Update or create only the release, using a pre-existing tag and attached assets:

  ```yaml
  ---
  name: Publish Release Assets

  on:
    workflow_dispatch:

  jobs:
    release:
      runs-on: docker
      steps:
        - name: Publish release assets
          uses: redjax/PipelineTemplates/.forgejo/actions/tag-release@branch-tag-or-ref
          with:
            tag-name: v1.2.3
            create-tag: "false"
            create-release: "true"
            release-name: "v1.2.3"
            release-notes-path: ./release-notes.md
            artifact-path: ./dist
            asset-glob: "*.zip"
            draft: "false"
            prerelease: "false"
            overwrite-assets: "true"
  ```
