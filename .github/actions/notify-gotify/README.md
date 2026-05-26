# Github Action: Send Gotify notification

This Action sends notifications to a Gotify server. It supports simple text notifications, markdown rendering, clickable URLs, large images, extras merging, and full raw JSON payload overrides.

## Inputs

- `gotify-url`: Base URL of the Gotify server, for example `https://gotify.example.com`. Required.
- `gotify-token`: Gotify application token used to authenticate the request. Required.
- `title`: Optional notification title.
- `message`: Notification message body. Required unless `raw-json-payload` is provided.
- `priority`: Gotify priority as a string, e.g. `"0"`, `"5"`, `"10"`. Default: `"0"`.
- `use-json`: `"true"` to send a JSON payload, `"false"` to send multipart/form-data (`title`/`message`/`priority` only). Default: `"true"`.
- `content-type`: Content type used by the client for rendering, e.g. `text/plain` or `text/markdown`. Default: `"text/plain"`.
- `click-url`: URL opened when the notification is clicked in the client. Optional.
- `big-image-url`: URL of a large image to display in the notification. Optional.
- `intent-url`: Android intent URL to trigger when the notification is received. Optional.
- `extras-json`: Additional JSON extras merged into the generated extras object. Must be a JSON object string. Default: `"{}"`.
- `raw-json-payload`: Complete JSON payload to send as-is. When set, it overrides the generated payload built from `title`, `message`, `priority`, and `extras`. Optional.
- `user-agent`: HTTP User‑Agent string to send with the request. Default: `"redjax/PipelineTemplates"`.
- `debug`: `"true"` to enable extra logging and non‑silent curl; `"false"` for quieter output. Default: `"false"`.

## Usage

- Simple text notification:

  ```yaml
  ---
  name: Notify Gotify (simple)

  on:
    workflow_dispatch:

  jobs:
    notify:
      runs-on: ubuntu-latest
      steps:
        - name: Simple notification
          uses: redjax/PipelineTemplates/.github/actions/notify-gotify@gh/notify-gotify/v0.0.1
          with:
            gotify-url: ${{ vars.GOTIFY_URL }}
            gotify-token: ${{ secrets.GOTIFY_TOKEN }}
            title: "CI Pipeline"
            message: "Build finished successfully."
            priority: "3"
            use-json: "true"
            content-type: "text/plain"
            click-url: ""
            big-image-url: ""
            intent-url: ""
            extras-json: "{}"
            raw-json-payload: ""
            user-agent: "redjax/PipelineTemplates"
            debug: "false"
  ```

- Clickable markdown notification linking back to the workflow run:

```yaml
---
name: Notify Gotify (markdown + link)

on:
  workflow_dispatch:

jobs:
  notify:
    runs-on: ubuntu-latest
    steps:
      - name: Markdown notification
        uses: redjax/PipelineTemplates/.github/actions/notify-gotify@gh/notify-gotify/v0.0.1
        with:
          gotify-url: ${{ vars.GOTIFY_URL }}
          gotify-token: ${{ secrets.GOTIFY_TOKEN }}
          title: "Pipeline Test"
          message: |
            ## CI Run Completed

            - Repo: `${{ github.repository }}`
            - Branch: `${{ github.ref_name }}`
            - Commit: `${{ github.sha }}`
          priority: "8"
          use-json: "true"
          content-type: "text/markdown"
          click-url: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
          big-image-url: ""
          intent-url: ""
          extras-json: "{}"
          raw-json-payload: ""
          user-agent: "redjax/PipelineTemplates"
          debug: "false"
```

- Raw JSON payload override example:

  ```yaml
  ---
  name: Notify Gotify (raw JSON)

  on:
    workflow_dispatch:

  jobs:
    notify:
      runs-on: ubuntu-latest
      steps:
        - name: Raw JSON notification
          uses: redjax/PipelineTemplates/.github/actions/notify-gotify@gh/notify-gotify/v0.0.1
          with:
            gotify-url: ${{ vars.GOTIFY_URL }}
            gotify-token: ${{ secrets.GOTIFY_TOKEN }}
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
            title: ""
            message: ""
            priority: "0"
            use-json: "true"
            content-type: "text/plain"
            click-url: ""
            big-image-url: ""
            intent-url: ""
            extras-json: "{}"
            user-agent: "redjax/PipelineTemplates"
            debug: "false"
  ```

- Big image notification:

  ```yaml
  ---
  name: Notify Gotify (big image)

  on:
    workflow_dispatch:

  jobs:
    notify:
      runs-on: ubuntu-latest
      steps:
        - name: Big image notification
          uses: redjax/PipelineTemplates/.github/actions/notify-gotify@gh/notify-gotify/v0.0.1
          with:
            gotify-url: ${{ vars.GOTIFY_URL }}
            gotify-token: ${{ secrets.GOTIFY_TOKEN }}
            title: "Deployment Complete"
            message: "Production deployment finished successfully."
            priority: "5"
            use-json: "true"
            content-type: "text/plain"
            click-url: ""
            big-image-url: "https://example.com/images/deploy-success.png"
            intent-url: ""
            extras-json: "{}"
            raw-json-payload: ""
            user-agent: "redjax/PipelineTemplates"
            debug: "false"
  ```

- Multipart (form-data) notification:

  ```yaml
  ---
  name: Notify Gotify (multipart)

  on:
    workflow_dispatch:

  jobs:
    notify:
      runs-on: ubuntu-latest
      steps:
        - name: Multipart notification
          uses: redjax/PipelineTemplates/.github/actions/notify-gotify@gh/notify-gotify/v0.0.1
          with:
            gotify-url: ${{ vars.GOTIFY_URL }}
            gotify-token: ${{ secrets.GOTIFY_TOKEN }}
            use-json: "false"  # switch to multipart/form-data mode
            title: "CI Pipeline"
            message: |
              This notification was sent using multipart/form-data mode.

              Only title, message, and priority are supported in this mode.
            priority: "2"
            content-type: "text/plain"
            click-url: ""
            big-image-url: ""
            intent-url: ""
            extras-json: "{}"
            raw-json-payload: ""
            user-agent: "redjax/PipelineTemplates"
            debug: "false"
  ```

- Merged extras (custom metadata):

  ```yaml
  ---
  name: Notify Gotify (merged extras)

  on:
    workflow_dispatch:

  jobs:
    notify:
      runs-on: ubuntu-latest
      steps:
        - name: Notification with merged extras
          uses: redjax/PipelineTemplates/.github/actions/notify-gotify@gh/notify-gotify/v0.0.1
          with:
            gotify-url: ${{ vars.GOTIFY_URL }}
            gotify-token: ${{ secrets.GOTIFY_TOKEN }}
            title: "Deploy pipeline"
            message: "Production deploy finished with status: SUCCESS."
            priority: "7"
            use-json: "true"
            content-type: "text/plain"
            click-url: ""
            big-image-url: ""
            intent-url: ""
            extras-json: |
              {
                "custom::ci": {
                  "pipeline": "deploy",
                  "environment": "production",
                  "run_id": "${{ github.run_id }}",
                  "commit": "${{ github.sha }}"
                }
              }
            raw-json-payload: ""
            user-agent: "redjax/PipelineTemplates"
            debug: "false"
  ```

- A caller can pass inputs into the workflow and forward them into the action, instead of hard‑coding title/message.

  ```yaml
  ---
  name: Notify Gotify (parameterized)

  on:
    workflow_dispatch:
      inputs:
        title:
          description: "Notification title"
          required: false
          type: string
          default: "CI Notification"
        message:
          description: "Notification message"
          required: true
          type: string
        priority:
          description: "Notification priority"
          required: false
          type: string
          default: "5"

  jobs:
    notify:
      runs-on: ubuntu-latest
      steps:
        - name: Parameterized notification
          uses: redjax/PipelineTemplates/.github/actions/notify-gotify@gh/notify-gotify/v0.0.1
          with:
            gotify-url: ${{ vars.GOTIFY_URL }}
            gotify-token: ${{ secrets.GOTIFY_TOKEN }}
            title: ${{ inputs.title }}
            message: ${{ inputs.message }}
            priority: ${{ inputs.priority }}
            use-json: "true"
            content-type: "text/plain"
            click-url: ""
            big-image-url: ""
            intent-url: ""
            extras-json: "{}"
            raw-json-payload: ""
            user-agent: "redjax/PipelineTemplates"
            debug: "false"
  ```

- Create an Android intent:

  ```yaml
  ---
  name: Notify Gotify (Android intent)

  on:
    workflow_dispatch:

  jobs:
    notify:
      runs-on: ubuntu-latest
      steps:
        - name: Android intent notification
          uses: redjax/PipelineTemplates/.github/actions/notify-gotify@gh/notify-gotify/v0.0.1
          with:
            gotify-url: ${{ vars.GOTIFY_URL }}
            gotify-token: ${{ secrets.GOTIFY_TOKEN }}
            title: "Mobile Alert"
            message: "Tap to open the CI dashboard app."
            priority: "9"
            use-json: "true"
            content-type: "text/plain"
            click-url: ""
            big-image-url: ""
            intent-url: "android-app://com.example.ci.dashboard"
            extras-json: "{}"
            raw-json-payload: ""
            user-agent: "redjax/PipelineTemplates"
            debug: "false"
  ```
