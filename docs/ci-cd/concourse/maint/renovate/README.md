# Concourse - Renovate Pipeline <!-- omit in toc -->

The [`renovate` Concourse pipeline](../../../../../.concourse/maint/renovate/tasks/renovate.yml) runs Renovate against a target repository using the shared Renovate task in `.concourse/maint/renovate/`.

It is designed to be copied into a consuming repository as a small stub pipeline, while the actual Renovate logic lives in the central `PipelineTemplates` repository.

> [!NOTE]
> This pipeline is built around running Renovate as a shared Concourse task. The consuming repository must provide:
>
> - A target repository resource to clone.
>   - This can be the calling repository itself. For example, if calling this pipeline from `username/ex-repo`, you can provide `username/ex-repo` as the target repository to clone.
> - A checkout of the `PipelineTemplates` repository.
> - A platform endpoint if the repository host requires one.
>   - For example, some hosts require an API base URL such as `https://host.example/api/v1`.
> - A Renovate token with the required permissions.
>   - Each platform may name these permissions differently, but at minimum Renovate needs permissions equivalent to:
>     - Organization or group access: READ
>     - Issues: WRITE
>     - Repository or contents: WRITE
>     - User: READ
> - A schedule or trigger resource if it should run automatically.

The pipeline is typically deployed from the consuming repository, not from `PipelineTemplates` itself. The consuming repo owns the values for the target repository, credentials, and any schedule behavior.

## Table of Contents <!-- omit in toc -->

- [Responsibilities](#responsibilities)
- [Inputs](#inputs)
- [Secrets](#secrets)
- [Example use](#example-use)
- [Notes](#notes)
  - [Base branch behavior](#base-branch-behavior)
  - [Platform endpoint](#platform-endpoint)
  - [Token permissions](#token-permissions)
  - [Scheduling](#scheduling)

## Responsibilities

- Clone the target repository.
- Clone the `PipelineTemplates` repository.
- Trigger Renovate on a schedule or on demand.
- Pass runtime configuration into the Renovate task.
- Create or update dependency pull requests in the target repository.
- Create or update the Dependency Dashboard issue when enabled.

## Inputs

The consuming repository must provide these values through Concourse vars:

- `target_repo_uri`: Git URI for the target repository.
- `target_repo_branch`: Branch to clone from the target repository.
- `templates_repo_uri`: Git URI for the `PipelineTemplates` repository.
- `templates_repo_branch`: Branch to clone from `PipelineTemplates`.
- `platform`: Renovate platform value, such as `forgejo`, `github`, `gitlab`, or `codeberg`.
- `mode`: Renovate execution mode, usually `run`.
- `renovate_endpoint`: API base URL for the repository host, if required.
- `target_repo`: Target repository in `owner/name` format.
- `log_level`: Renovate log level.
- `config_file`: Renovate config file path.
- `require_config`: Whether Renovate requires a config file.
- `autodiscover`: Whether Renovate should autodiscover repositories.
- `renovate_author_email`: Email address used for the Renovate bot author.
- `base_branches`: Base branch or branches Renovate should target.
- `use_base_branch_config`: Whether Renovate should use base branch config.
- `schedule resource`: A time-based trigger if the pipeline should run automatically.

## Secrets

The consuming repository must provide these secrets through Concourse vars or another secret source:

- `target_repo_private_key`: SSH private key for cloning the target repository.
- `templates_repo_private_key`: SSH private key for cloning the `PipelineTemplates` repository.
- `renovate_token`: Token used by Renovate to authenticate with the target host.
- `github_api_token`: GitHub token used for any GitHub access required by the pipeline templates.

> [!WARNING]
> Storing secrets in a plain vars file is convenient for local testing, but it is not a safe long-term pattern. Prefer a vault, secret manager, or environment-backed secret injection for real deployments.

## Example use

A consuming repository can copy the pipeline stub from [`examples/renovate.yml`](./examples/renovate.yml) and adapt it to its own repository and branch names.

The pipeline stub:

- Defines a git resource for the target repository.
- Defines a git resource for `PipelineTemplates`.
- Defines a `time` resource that triggers the pipeline every 6 hours.
- Runs the shared Renovate task from `.concourse/maint/renovate/tasks/renovate.yml`.
- Passes in runtime config and secret values using Concourse parameters.

The corresponding vars file can be copied from [`examples/vars/example.renovate.vars.yml`](./examples/vars/example.renovate.vars.yml), and the corresponding secrets file can be copied from [`examples/vars/example.renovate.secrets.yml`](./examples/vars/example.renovate.secrets.yml).

## Notes

### Base branch behavior

If `base_branches` is set, Renovate will only scan the listed branches. The branch must exist in the target repository, or Renovate will skip it and report a repository problem in the Dependency Dashboard.

### Platform endpoint

Some repository hosts require an API endpoint, while others do not. When required, `renovate_endpoint` must point to the correct API base for the host in use.

### Token permissions

The Renovate token must be valid for the repository host in use and able to authenticate as the Renovate bot user. If the token is invalid or lacks the required permissions, Renovate will fail during initialization.

### Scheduling

The example pipeline uses a `time` resource with `interval: 6h`. If the consuming repository wants a different schedule, it can change that interval or replace the trigger logic entirely.
