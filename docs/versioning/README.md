# Versioning

Pipeline components in this repository are versioned with semantic versioning, i.e. `0.0.1`. Bumping versions is handled by the [`bump-my-version` tool](https://github.com/callowayproject/bump-my-version).

Each component has a `VERSION` file, which simply contains the current version of that component, and a `.bumpversion.toml` which tells the `bump-my-version` tool how to update the component. The config file assumes you are running the `bump-my-version` command from the root of the repository.

For example, the [`demo-hello.yml` Github Action component](../../.github/actions/hello) is a versioned component. To bump it from `0.0.1` to `0.0.2`, this is the command you would run from the root of the repository:

```shell
bump-my-version bump patch --config-file .github/actions/hello/.bumpversion.toml
```

The `bump-my-version` tool will find the `.bumpversion.toml` config, update the `VERSION` file to `0.0.2`, and will update the `current_version` in the `[tool.bumpversion]` section.
