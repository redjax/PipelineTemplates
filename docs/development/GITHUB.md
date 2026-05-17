# PipelineTemplates - GitHub Workflows & Actions <!-- omit in toc -->

GitHub provides two main reusable CI/CD building blocks: actions and reusable workflows.

- **Actions** are reusable units of work, such as a JavaScript action, Docker action, or composite action.
- **Reusable workflows** are full workflows that can be called from another workflow.

- [GitHub Actions docs](https://docs.github.com/en/actions)
- [GitHub reusable workflows docs](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows)

## Checkout PipelineTemplates from a calling repository

When a repository calls a reusable workflow from PipelineTemplates, GitHub runs the workflow file from the referenced ref, but it does not automatically make the rest of that repository’s files available on disk. If the workflow needs to run helper scripts or read other files from PipelineTemplates, it should check out the PipelineTemplates repository itself before running those files.

For workflows that need access to files in the same repository as the reusable workflow, the safest pattern is to parse `github.workflow_ref` and use that to determine the exact repository and ref to check out. That keeps the workflow definition and the helper files on the same version, which avoids mismatches between the workflow file and the scripts it calls.

### Example

In [`notify-gotify.yml`](../../.github/workflows/notify-gotify.yml), I check out PipelineTemplates so the workflow can run [`shared/scripts/bash/gotify/send-notification.sh`](../../shared/scripts/bash/gotify/send-notification.sh) from the same repository version as the reusable workflow:

```yaml
- name: Checkout PipelineTemplates repo
  uses: actions/checkout@v6
  with:
    repository: redjax/PipelineTemplates
    ## `github.ref` uses the ref from the calling repo
    ref: ${{ github.ref }}
    path: pipelinetemplates
```

This pattern works when the workflow intentionally wants the caller’s `ref`, but a better long-term approach is to derive the repository and `ref` from `github.workflow_ref` so the checkout matches the reusable workflow version that was invoked.

For example:

```yaml
---
## Name, triggers, permissions, etc

steps:
  - name: Checkout caller repo
    uses: actions/checkout@v6

  ## Get the ref from the calling repository
  - name: Parse workflow reference
    id: workflow-ref
    run: |
      WORKFLOW_REF="${{ github.workflow_ref }}"
      REPO="${WORKFLOW_REF%%/.github/*}"
      REF="${WORKFLOW_REF##*@}"
      echo "repository=$REPO" >> "$GITHUB_OUTPUT"
      echo "ref=$REF" >> "$GITHUB_OUTPUT"
      echo "Parsed workflow ref: repo=$REPO, ref=$REF"

  ## Checkout PipelineTemplates at the parsed ref
  - name: Checkout PipelineTemplates repo
    uses: actions/checkout@v6
    with:
      repository: ${{ steps.workflow-ref.outputs.repository }}
      ref: ${{ steps.workflow-ref.outputs.ref }}
      path: pipelinetemplates

  ## Do something, i.e. run the go-build script
  - name: Run build script
    run: bash pipelinetemplates/shared/scripts/bash/go/go-build.sh
```

This approach keeps the reusable workflow and its helper files in sync. If a caller repository invokes `PipelineTemplates/.github/workflows/go-build.yml@github/go-build/v0.0.4`, the reusable workflow can read `github.workflow_ref`, extract `redjax/PipelineTemplates` and `refs/tags/github/go-build/v0.0.4`, and then check out that exact ref before running `shared/scripts/bash/go/go-build.sh`.
