# Forgejo Pipelines

[Forgejo Actions](https://forgejo.org/docs/next/user/actions/reference/) is Forgejo's equivalent to Github Actions, and in fact is compatible with many of the same components.

## Calling Actions

If this repository is hosted on your Forgejo instance, you can leave the `uses:` lines in your calling pipelines as `uses: redjax/PipelineTemplates/.forgejo/actions/...`. If the code is hosted somewhere else, i.e. Github, you should use a full URL instead, like `uses: https://github.com/redjax/PipelineTemplates/.forgejo/actions/action-name@branch-tag-or-ref`.
