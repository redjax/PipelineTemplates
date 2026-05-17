# Gotify Notification Pipeline <!-- omit in toc -->

- Pipeline: [`.github/workflows/notify-gotify.yml`](../../../../.github/workflows/notify-gotify.yml)

Send a notification to a [Gotify](https://gotify.net) server.

## Table of Contents <!-- omit in toc -->

- [Requirements](#requirements)
  - [Repository Variables](#repository-variables)
  - [Repository Secrets](#repository-secrets)
- [Inputs](#inputs)
- [Workflow Reference](#workflow-reference)
- [JSON vs Multipart Mode](#json-vs-multipart-mode)
- [Example calling pipelines](#example-calling-pipelines)
  - [Manual run, predefined messages](#manual-run-predefined-messages)
  - [As a pipeline step](#as-a-pipeline-step)
- [Links](#links)

## Requirements

The calling repository must define:

### Repository Variables

| Name         | Description                   |
| ------------ | ----------------------------- |
| `GOTIFY_URL` | Base URL of the Gotify server |

### Repository Secrets

| Name           | Description              |
| -------------- | ------------------------ |
| `GOTIFY_TOKEN` | Gotify application token |

## Inputs

| Input              | Type    | Default                    | Description                                |
| ------------------ | ------- | -------------------------- | ------------------------------------------ |
| `gotify-url`       | string  | required                   | Base URL of the Gotify server              |
| `title`            | string  | `""`                       | Notification title                         |
| `message`          | string  | `""`                       | Notification message                       |
| `priority`         | number  | `0`                        | Notification priority                      |
| `use-json`         | boolean | `true`                     | Use JSON payload instead of multipart form |
| `content-type`     | string  | `text/plain`               | Notification rendering type                |
| `click-url`        | string  | `""`                       | URL opened when notification is clicked    |
| `big-image-url`    | string  | `""`                       | Large notification image                   |
| `intent-url`       | string  | `""`                       | Android intent URL                         |
| `extras-json`      | string  | `{}`                       | Additional Gotify extras JSON              |
| `raw-json-payload` | string  | `""`                       | Override generated payload entirely        |
| `user-agent`       | string  | `redjax/PipelineTemplates` | HTTP User-Agent                            |
| `debug`            | boolean | `false`                    | Enable debug logging                       |

## Workflow Reference

Reference this reusable workflow from another repository (tagging format is: `github/notify-gotify/<version>`):

```yaml
uses: redjax/PipelineTemplates/.github/workflows/notify-gotify.yml@github/notify-gotify/vx.x.x
```

## JSON vs Multipart Mode

By default, notifications are sent as `application/json`.

JSON mode supports:

- Markdown
- Clickable notifications
- Images
- Extras
- Android actions
- Raw payload overrides

Multipart mode (`use-json: false`) is intended for compatibility scenarios and only supports:

- `title`
- `message`
- `priority`

## Example calling pipelines

See the sections below for examples detailing calling this pipeline from another repository.

A simple notification step might look like:

```yaml
---
jobs:
  notify:
    uses: redjax/PipelineTemplates/.github/workflows/notify-gotify.yml@github/notify-gotify/v0.0.2

    with:
      gotify-url: ${{ vars.GOTIFY_URL }}
      title: CI Complete
      message: Build completed successfully

    secrets:
      gotify-token: ${{ secrets.GOTIFY_TOKEN }}

```

### Manual run, predefined messages

Below is a unified test pipeline demonstrating all supported notification types. When manually triggered, users can select which notification variants to send.

```yaml
---
###################################################
# Unified test pipeline for Gotify notifications. #
###################################################

name: Test Gotify Notifications

on:
  workflow_dispatch:
    inputs:
      simple:
        description: "Run simple notification"
        required: false
        default: false
        type: boolean

      clickable:
        description: "Run clickable notification"
        required: false
        default: false
        type: boolean

      markdown:
        description: "Run markdown notification"
        required: false
        default: false
        type: boolean

      big-image:
        description: "Run image notification"
        required: false
        default: false
        type: boolean

      multipart:
        description: "Run multipart form notification"
        required: false
        default: false
        type: boolean

      merged-extras:
        description: "Run merged extras notification"
        required: false
        default: false
        type: boolean

      raw-json:
        description: "Run raw JSON payload notification"
        required: false
        default: false
        type: boolean

env:
  GOTIFY_URL: ${{ vars.GOTIFY_URL }}

jobs:
  simple:
    if: inputs.simple
    uses: redjax/PipelineTemplates/.github/workflows/notify-gotify.yml@github/notify-gotify/v0.0.2

    with:
      gotify-url: ${{ vars.GOTIFY_URL }}
      title: Pipeline Test
      message: Simple Gotify notification test
      priority: 3

    secrets:
      gotify-token: ${{ secrets.GOTIFY_TOKEN }}

  clickable:
    if: inputs.clickable
    uses: redjax/PipelineTemplates/.github/workflows/notify-gotify.yml@github/notify-gotify/v0.0.2

    with:
      gotify-url: ${{ vars.GOTIFY_URL }}
      title: Pipeline Test
      message: Click to open workflow run
      click-url: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
      priority: 5

    secrets:
      gotify-token: ${{ secrets.GOTIFY_TOKEN }}

  markdown:
    if: inputs.markdown
    uses: redjax/PipelineTemplates/.github/workflows/notify-gotify.yml@github/notify-gotify/v0.0.2

    with:
      gotify-url: ${{ vars.GOTIFY_URL }}
      title: Pipeline Test
      content-type: text/markdown
      message: |
        ## Pipeline Test - Markdown

        This is a test notification from:

        - Repository: `${{ github.repository }}`
        - Branch: `${{ github.ref_name }}`
        - Commit: `${{ github.sha }}`

      priority: 8

    secrets:
      gotify-token: ${{ secrets.GOTIFY_TOKEN }}

  big-image:
    if: inputs.big-image
    uses: redjax/PipelineTemplates/.github/workflows/notify-gotify.yml@github/notify-gotify/v0.0.2

    with:
      gotify-url: ${{ vars.GOTIFY_URL }}
      title: Pipeline Test
      message: Test notification with embedded image
      big-image-url: https://res.cloudinary.com/utiblog/image/upload/f_auto,q_auto/pipeline-welder_hero.webp
      priority: 5

    secrets:
      gotify-token: ${{ secrets.GOTIFY_TOKEN }}

  multipart:
    if: inputs.multipart
    uses: redjax/PipelineTemplates/.github/workflows/notify-gotify.yml@github/notify-gotify/v0.0.2

    with:
      gotify-url: ${{ vars.GOTIFY_URL }}
      use-json: false
      title: Pipeline Test
      message: |
        This notification was sent using multipart/form-data mode.

        Only title, message, and priority are supported.
      priority: 2

    secrets:
      gotify-token: ${{ secrets.GOTIFY_TOKEN }}

  merged-extras:
    if: inputs.merged-extras
    uses: redjax/PipelineTemplates/.github/workflows/notify-gotify.yml@github/notify-gotify/v0.0.2

    with:
      gotify-url: ${{ vars.GOTIFY_URL }}
      title: Pipeline Test
      message: Test notification with merged extras
      extras-json: |
        {
          "custom::ci": {
            "pipeline": "deploy",
            "environment": "production"
          }
        }

    secrets:
      gotify-token: ${{ secrets.GOTIFY_TOKEN }}

  raw-json:
    if: inputs.raw-json
    uses: redjax/PipelineTemplates/.github/workflows/notify-gotify.yml@github/notify-gotify/v0.0.2

    with:
      gotify-url: ${{ vars.GOTIFY_URL }}
      raw-json-payload: |
        {
          "title": "Pipeline Test",
          "message": "Raw JSON payload test",
          "priority": 10,
          "extras": {
            "client::display": {
              "contentType": "text/markdown"
            }
          }
        }

    secrets:
      gotify-token: ${{ secrets.GOTIFY_TOKEN }}

```

### As a pipeline step

You can add a step to a pipeline to send a Gotify notification, i.e. on a job failure.

For example, sending a simple notification when a build fails:

```yaml
---
name: Build Application

on:
  push:
    branches:
      - main

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v6

      - name: Simulate build
        run: |
          echo "Building application..."
          exit 1

  notify-failure:
    name: Send failure notification
    needs:
      - build

    ## Only run if the build job failed
    if: failure()

    uses: redjax/PipelineTemplates/.github/workflows/notify-gotify.yml@github/notify-gotify/v0.0.1

    with:
      gotify-url: ${{ vars.GOTIFY_URL }}

      title: "GitHub Actions Failure"

      message: |
        Repository: ${{ github.repository }}
        Workflow: ${{ github.workflow }}
        Branch: ${{ github.ref_name }}

        The build job failed.

      priority: 8

      click-url: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}

      content-type: text/plain

    secrets:
      gotify-token: ${{ secrets.GOTIFY_TOKEN }}

```

Or a Markdown-formatted notification:

```yaml
---
name: Deploy Application

on:
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Deploy app
        run: exit 1

  notify-failure:
    needs:
      - deploy

    if: failure()

    uses: redjax/PipelineTemplates/.github/workflows/notify-gotify.yml@github/notify-gotify/v0.0.1

    with:
      gotify-url: ${{ vars.GOTIFY_URL }}

      title: "Deployment Failed"

      content-type: text/markdown

      message: |
        ## Deployment Failed

        **Repository:** `${{ github.repository }}`
        **Branch:** `${{ github.ref_name }}`

        [Open Workflow Run](
          ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
        )

      click-url: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}

      priority: 10

    secrets:
      gotify-token: ${{ secrets.GOTIFY_TOKEN }}

```

## Links

- [Gotify home](https://gotify.net)
- [Gotify docs](https://gotify.net/docs/)
- [Gotify Github](https://github.com/gotify)
