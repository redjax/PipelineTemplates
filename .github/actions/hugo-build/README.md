# Github Action: Hugo Build

This Action builds a Hugo site with optional cache restore/save, change detection, and artifact publishing. It is designed to work for both flat layouts (`config.toml` and content at the repo root) and monorepo layouts (site in a subdirectory, i.e. `docs/site/` or `apps/site/`), as long as the action is pointed at the correct `source-dir`.

## Inputs

- `hugo-version`: Hugo version to install with `peaceiris/actions-hugo`. Default: `0.161.1`.
  - `0.161.1`
  - `0.150.0`
  - `latest` if you want to track a moving version
- `extended`: Use the extended Hugo binary. Default: `"true"`.
  - `"true"` for SCSS/SASS and other extended features
  - `"false"` for plain Hugo builds
- `source-dir`: Path to the Hugo project root. Default: `.`.
  - `.`
  - `docs`
  - `apps/site`
- `public-dir`: Output directory for the built site. Default: `public`.
  - `public`
  - `dist`
  - `out`
- `base-url`: Optional base URL override. Leave empty to use site config. Default: `""`.
  - `https://example.com/`
  - `https://example.com/docs/`
- `environment`: Hugo environment passed to `hugo -e/--environment`. Default: `production`.
  - `production`
  - `staging`
  - `preview`
- `build-flags`: Extra flags passed to Hugo. Default: `--gc --minify`.
  - `--gc --minify`
  - `--gc --minify --enableGitInfo`
  - `--gc --minify --buildFuture`
- `use-cache`: Enable cache restore/save for Hugo-related build inputs. Default: `"true"`.
  - `"true"`
  - `"false"`
- `cache-key-suffix`: Optional suffix to differentiate caches. Default: `""`.
  - `docs`
  - `staging`
- `check-changed`: If true, detect changed files and skip the build when nothing relevant changed. Default: `"false"`.
  - `"true"`
  - `"false"`
- `changed-paths-mode`: How custom changed paths are applied. Default: `default`.
  - `default`
  - `replace`
  - `append`
- `changed-paths`: Newline-delimited glob patterns. Used when `changed-paths-mode` is `replace` or `append`. Default: `""`.
  - `content/**`
  - `layouts/**`
  - `static/**`
  - `themes/**`
- `publish-artifact`: Publish the built site as a workflow artifact. Default: `"false"`.
  - `"true"`
  - `"false"`
- `artifact-name`: Artifact name for the built site. Default: `hugo-site`.
  - `hugo-site`
  - `docs-site`
  - `preview-site`
- `artifact-retention-days`: Number of days to retain the artifact. Default: `7`.
  - `7`
  - `14`
  - `30`
- `artifact-if-no-files-found`: What to do if no files are found. Default: `error`.
  - `error`
  - `warn`
  - `ignore`

## Outputs

- `hugo-changed`: Whether relevant Hugo files changed.
  - `true`
  - `false`

## Usage

### Flat repo

Flat repo, Hugo site at the repository root:

```yaml
---
name: Build Hugo (flat)

on:
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v7

      - name: Build Hugo site
        uses: redjax/PipelineTemplates/.github/actions/hugo-build@gh/hugo-build/v0.0.1
        with:
          hugo-version: "0.161.1"
          extended: "true"
          source-dir: .
          public-dir: public
          base-url: ""
          environment: production
          build-flags: --gc --minify
          use-cache: "true"
          check-changed: "true"
          publish-artifact: "true"
          artifact-name: hugo-site
```

### Monorepo/nested Hugo site

```yaml
---
name: Build Hugo (monorepo)

on:
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v7

      - name: Build Hugo site from apps/site
        uses: redjax/PipelineTemplates/.github/actions/hugo-build@gh/hugo-build/v0.0.1
        with:
          hugo-version: "0.161.1"
          extended: "true"
          source-dir: apps/site
          public-dir: public
          base-url: ""
          environment: production
          build-flags: --gc --minify
          use-cache: "true"
          check-changed: "true"
          changed-paths-mode: append
          changed-paths: |
            apps/site/**
            themes/**
            shared/**
          publish-artifact: "true"
          artifact-name: hugo-site
```

## Notes

- This action installs Hugo, runs a build, and can upload the resulting site directory as an artifact.
- `source-dir` should point at the folder that contains your Hugo config file and content tree.
- `public-dir` should match the Hugo output directory you want to publish later.
- If `check-changed` is enabled, the action can skip the build when no relevant files changed, which is useful for large repos or documentation sites.
- The cache includes Hugo’s cache and common project cache directories to speed up repeated builds.
- If you publish the artifact, the artifact path is the generated site directory under `source-dir/public-dir`
