# GitHub Action: Astro Build

This action detects [Astro](https://astro.build/) build-relevant changes, installs Node.js dependencies, builds an Astro site, and validates the generated static output. It supports both flat repository layouts—where the Astro project is at the repository root—and monorepo/nested layouts, such as `site/`, `docs/site/`, or `apps/marketing/`.

The action separates three paths deliberately:

- `working-directory`: where the configured build command executes.
- `astro-project-dir`: where the Astro project’s package.json and astro.config.* live.
- `output-dir`: the repository-relative generated site directory that the action cleans and validates.

For most Astro sites, `astro-project-dir` is the directory containing `package.json`, and Astro’s conventional build output is `dist/`. Astro compiles source/assets into its deployable output directory.

## Inputs

- `working-directory`: Repository-relative directory from which build-command runs. Default: `.`.
  - `.`
  - `site`
  - `apps/marketing`
- `astro-project-dir`: Repository-relative directory containing the Astro project’s `package.json` and `astro.config.*`. Default: `.`.
  - `.`
  - `site`
  - `apps/marketing`
- `output-dir`: Repository-relative path where the generated static site is expected. Default: `dist`.
  - `dist`
  - `site/dist`
  - `apps/marketing/dist`
  - `build/marketing-site`
- `node-version`: Node.js version installed before dependency installation and build. Default: `26`.
  - `26`
  - `24`
  - `22`
  - `20.19.0`
- `install-command`: Command used to install dependencies. It runs from astro-project-dir. Default: `npm ci`.
  - `npm ci`
  - `pnpm install --frozen-lockfile`
  - `yarn install --immutable`
- `build-command`: Command that builds the Astro site. It runs from working-directory. Default: `npm run build`.
  - `npm run build`
  - `./scripts/astro/build.sh`
  - `npm --prefix site run build`
- `clean`: Remove the existing output-dir before building. Default: `"true"`.
  - `"true"`
  - `"false"`
- `check-changed`: Detect Astro-relevant file changes before installing dependencies and building. When no relevant changes are found, the action skips the install/build steps. Default: `"false"`.
  - `"true"`
  - `"false"`
- `changed-paths-mode`: How changed-paths is applied. Default: `default`.
  - `default`: Use the Astro action’s standard watched paths.
  - `replace`: Watch only the paths supplied in `changed-paths`.
  - `append`: Watch the standard paths plus paths supplied in `changed-paths`.
- `changed-paths`: Newline-delimited repository-relative Git pathspecs. Used when `changed-paths-mode` is replace or append. Default: `""`.
  - `site/**`
  - `shared/ui/**`
  - `scripts/astro/**`
  - `packages/design-system/**`
- `use-node-cache`: Enable the npm dependency cache through actions/setup-node. Default: `"true"`.
  - `"true"`
  - `"false"`
- `debug-build`: Print additional build-state diagnostics, including resolved paths, Node/npm versions, and selected Astro project files. Default: `"false"`.
  - `"true"`
  - `"false"`

## Default change paths

When `check-changed: "true"` and `changed-paths-mode: default`, the action watches Astro project files and configuration relative to `astro-project-dir`:

```text
src/**
public/**
astro.config.*
package.json
package-lock.json
npm-shrinkwrap.json
pnpm-lock.yaml
yarn.lock
tsconfig.json
tailwind.config.*
postcss.config.*
wrangler.json
wrangler.jsonc
```

It also watches shared Astro build tooling in the repository:

```text
scripts/astro/**
scripts/install/node.sh
scripts/install/_common.sh
```

For a project configured as:

```text
astro-project-dir: site
```

the project-relative defaults resolve to:

```text
site/src/**
site/public/**
site/astro.config.*
site/package.json
site/package-lock.json
site/npm-shrinkwrap.json
site/pnpm-lock.yaml
site/yarn.lock
site/tsconfig.json
site/tailwind.config.*
site/postcss.config.*
site/wrangler.json
site/wrangler.jsonc
```

The action does not watch `output-dir`. Generated output such as `dist/` is a build product, not a source input. The caller still controls `output-dir`; it is used to clean old output, verify the new build, and later upload or deploy the exact generated directory.

## Outputs

- `astro-changed`: Whether the change detector found Astro-relevant changes.
  - `true`
  - `false`
  - This output is meaningful when `check-changed: "true"`.
- `should-build`: Whether the action decided to run dependency installation and the Astro build.
  - `true`
  - `false`
  - This is true when change detection is disabled. When change detection is enabled, it matches `astro-changed`.
- `working-directory`: Absolute resolved directory from which the build command ran.
  - Example: `/home/runner/work/example/example`
- `astro-project-dir`: Absolute resolved Astro project directory.
  - Example: `/home/runner/work/example/example/site`
- `output-dir`: Absolute resolved and validated static output directory.
  - Example: `/home/runner/work/example/example/site/dist`

## Usage

### Flat repository

Use this when `package.json`, `astro.config.mjs`, source files, and output are all at repository root.

```text
---
name: Build Astro site

on:
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v7
        with:
          fetch-depth: 2

      - name: Build Astro site
        id: astro
        uses: redjax/PipelineTemplates/.github/actions/astro-build@gh/astro-build/v0.0.1
        with:
          working-directory: "."
          astro-project-dir: "."
          output-dir: "dist"

          node-version: "24"
          install-command: "npm ci"
          build-command: "npm run build"

          clean: "true"
          check-changed: "true"
          use-node-cache: "true"
          debug-build: "false"
```

With this configuration, the action Installs dependencies in `<repository root>`, runs build command from `<repository root>`, and validates output at `<repository root>/dist`.

### Nested Astro site

Use this when the Astro application lives in a subdirectory but a repository-level script controls the build.

This matches the first target repository structure:

```text
scripts/astro/build.sh
site/package.json
site/astro.config.mjs
site/src/
site/public/
site/dist/
```

```text
---
name: Build nested Astro site

on:
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v7
        with:
          fetch-depth: 2

      - name: Build Astro site from site/
        id: astro
        uses: redjax/PipelineTemplates/.github/actions/astro-build@gh/astro-build/v0.0.1
        with:
          working-directory: "."
          astro-project-dir: "site"
          output-dir: "site/dist"

          node-version: "24"
          install-command: "npm ci"
          build-command: "./scripts/astro/build.sh"

          clean: "true"
          check-changed: "true"
          changed-paths-mode: "append"
          changed-paths: |
            shared/**
            packages/design-system/**
          use-node-cache: "true"
          debug-build: "false"
```

With this configuration, the action installs dependencies in `<repository root>/site`, runs build command from `<repository root>`, and validates output at `<repository root>/site/dist`.

This is the preferred layout when your repository’s `scripts/astro/build.sh` determines the final `npm run build` behavior.

#### Nested project without a wrapper

If the build command does not require a repository-level wrapper, run it directly from the Astro project directory:

```text
---
name: Build nested Astro site directly

on:
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v7
        with:
          fetch-depth: 2

      - name: Build Astro application
        id: astro
        uses: redjax/PipelineTemplates/.github/actions/astro-build@gh/astro-build/v0.0.1
        with:
          working-directory: "apps/marketing"
          astro-project-dir: "apps/marketing"
          output-dir: "apps/marketing/dist"

          node-version: "24"
          install-command: "npm ci"
          build-command: "npm run build"

          clean: "true"
          check-changed: "true"
          use-node-cache: "true"
```

### Always build

Disable change detection when the workflow should always install dependencies and build—for example, during release workflows, manual debugging, or initial adoption.

```text
- name: Build Astro site
  uses: redjax/PipelineTemplates/.github/actions/astro-build@gh/astro-build/v0.0.1
  with:
    working-directory: "."
    astro-project-dir: "site"
    output-dir: "site/dist"
    build-command: "./scripts/astro/build.sh"

    check-changed: "false"
    clean: "true"
```

### Replace watched paths

Use `replace` when the default Astro watched paths do not represent your source layout:

```text
- name: Build Astro site
  uses: redjax/PipelineTemplates/.github/actions/astro-build@gh/astro-build/v0.0.1
  with:
    working-directory: "."
    astro-project-dir: "site"
    output-dir: "site/dist"
    build-command: "./scripts/astro/build.sh"

    check-changed: "true"
    changed-paths-mode: "replace"
    changed-paths: |
      site/**
      packages/ui/**
      scripts/astro/**
```

### Read the result

Use `should-build` when later workflow steps should run only after a build actually occurred:

```text
- name: Show build decision
  run: |
    echo "Astro relevant files changed: ${{ steps.astro.outputs.astro-changed }}"
    echo "Astro build ran: ${{ steps.astro.outputs.should-build }}"

- name: Upload generated site
  if: ${{ steps.astro.outputs.should-build == 'true' }}
  uses: actions/upload-artifact@v4
  with:
    name: astro-site
    path: ${{ steps.astro.outputs.output-dir }}
    if-no-files-found: error
    retention-days: 7
```
