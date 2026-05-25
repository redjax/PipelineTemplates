# Versioning

Pipeline components in this repository are versioned with semantic versioning, i.e. `0.0.1`. Bumping versions is handled by the [`bump-my-version` tool](https://github.com/callowayproject/bump-my-version).

Each component has a `VERSION` file, which simply contains the current version of that component, and a `.bumpversion.toml` which tells the `bump-my-version` tool how to update the component. The config file assumes you are running the `bump-my-version` command from the root of the repository.

For example, the [`demo-hello.yml` Github Action component](./.github/actions/hello) is a versioned component. To bump it from `0.0.1` to `0.0.2`, this is the command you would run from the root of the repository:

```shell
bump-my-version bump patch --config-file .github/actions/hello/.bumpversion.toml
```

The `bump-my-version` tool will find the `.bumpversion.toml` config, update the `VERSION` file to `0.0.2`, and will update the `current_version` in the `[tool.bumpversion]` section.

## Setting up new components

When you create a new component, you must add 2 files to start versioning the component automatically:

- `VERSION`: A file that simply tracks the version string for the component.
  - For new components, start by just writing `0.0.0` in the file.
  - The PR pipeline will detect the new component when merging into `main` and will automatically bump it to `0.0.1`.
- `.bumpversion.toml`: Configuration file for `bump-my-version`, the tool that creates new versions for changed components.
  - The standard `.bumpversion.toml` for this repository is:

    ```toml
    [tool.bumpversion]
    current_version = "0.0.0"
    commit = false
    tag = false

    [[tool.bumpversion.files]]
    filename = "path/to/component-name/VERSION"

    ```

    - Note: Change the `filename` value to the relative path from the root to the component.
    - For example, the [`go-build` Github Action](../.github/actions/go-build/) uses `.github/actions/go-build/VERSION` for the `filename` value.
