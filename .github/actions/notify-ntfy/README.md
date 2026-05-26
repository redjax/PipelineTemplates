# Github Action: Send Ntfy notification

Send notifications to an [Ntfy](https://ntfy.sh) server from inside a pipeline. Useful for notifying on pipeline events like a failure or detection.

## Inputs

- `ntfy-server`: Base URL of the ntfy server (self‑hosted or ntfy.sh).
  - `https://ntfy.sh`
  - `https://ntfy.example.com`
- `topic`: ntfy topic name to publish to.
  - `alerts`
  - `ci-builds`
  - `some-topicname`
- `title`: Notification title (`X-Title` header).
  - `Build completed`
  - `Deployment failed`
- `message`: Notification message body (HTTP body, unless `raw-body` is set).
  - `CI pipeline finished successfully.`
  - `Job ${{ github.job }} failed on ${{ runner.os }}`
- `priority`: ntfy priority (`X-Priority` header), `1–5` or `min|low|default|high|max`.
  - `default`
  - `high`
  - `5`
- `tags`: Comma‑separated ntfy tags (`X-Tags` header).
  - `ci,build,success`
  - `deploy,error,production`
- `click-url`: URL opened when the notification is tapped (`X-Click` header).
  - `${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}`
  - `https://status.example.com/incidents/1234`
- `actions`: Raw `X-Actions` header to define ntfy notification actions (for advanced use).
  - `view,View logs,https://logs.example.com/build/${GITHUB_RUN_ID}`
  - `ack,Acknowledge,ntfy://ack?id=1234`
- `attach`: Attachment URL or descriptor (`X-Attach` header).
  - `https://example.com/artifacts/report.pdf`
  - `https://example.com/screenshots/error.png`
- `raw-body`: Completely override the message body with raw content. Use for custom payloads or multi‑line messages.
  - `Build: ${{ github.run_number }}\nStatus: ${{ job.status }}`
  - JSON, markdown, or any text blob.
- `user-agent`: HTTP User-Agent header (default: `redjax/PipelineTemplates`).
  - `my-org/ci-notifier`
- `auth-token`: Bearer token for `Authorization: Bearer <token>`.
  - `${{ secrets.NTFY_TOKEN }}`
- `username`: Basic auth username (only used if `password` is also set).
  - `ci-bot`
- `password`: Basic auth password.
  - `${{ secrets.NTFY_PASSWORD }}`
- `debug`: Enable extra logging (`true`/`false`). When `true`, the script prints more detail and does not run curl in silent mode (default: `false`).
  - `true`

## Usage

- Simple success notification (public or token‑protected ntfy)

  ```yaml
  ---
  name: Notify on success

  on:
    push:
      branches: [ main ]

  jobs:
    notify:
      runs-on: ubuntu-latest
      steps:
        - name: Notify via ntfy (success)
          if: ${{ success() }}
          uses: redjax/PipelineTemplates/.github/actions/notify-ntfy@v0.0.1
          with:
            ntfy-server: https://ntfy.example.com
            topic: ci-builds
            title: "Build succeeded"
            message: "Workflow ${{ github.workflow }} finished successfully."
            priority: "default"
            tags: "github,ci,success"
            click-url: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
            auth-token: ${{ secrets.NTFY_TOKEN }}
  ```

- Failure‑only notification with higher priority
  
  ```yaml
  jobs:
    notify:
      runs-on: ubuntu-latest
      steps:
        - name: Notify via ntfy (failure)
          if: ${{ failure() }}
          uses: redjax/PipelineTemplates/.github/actions/notify-ntfy@v0.0.1
          with:
            ntfy-server: https://ntfy.example.com
            topic: ci-builds
            title: "Build FAILED"
            message: "Job ${{ github.job }} failed in ${{ github.workflow }}."
            priority: "high"
            tags: "github,ci,failure"
            click-url: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
            auth-token: ${{ secrets.NTFY_TOKEN }}
            debug: "true"
  ```

- Using basic auth and actions

  ```yaml
  jobs:
    notify:
      runs-on: ubuntu-latest
      steps:
        - name: Notify via ntfy with actions
          uses: redjax/PipelineTemplates/.github/actions/notify-ntfy@v0.0.1
          with:
            ntfy-server: https://ntfy.example.com
            topic: deployments
            title: "Deployment complete"
            message: "Env: production, Commit: ${{ github.sha }}"
            priority: "default"
            tags: "deploy,production"
            click-url: "https://deployments.example.com/${{ github.run_id }}"
            actions: "view,View logs,https://logs.example.com/${{ github.run_id }}"
            username: "ci-bot"
            password: ${{ secrets.NTFY_PASSWORD }}
  ```

- Multiline Markdown messages:
  - This sends a multi‑line body to the `ci-builds topic`
  - If your client has Markdown enabled, it will render as a formatted list with headings.

  ```yaml
  jobs:
    notify:
      runs-on: ubuntu-latest
      steps:
        - name: Notify via ntfy (multi-line markdown)
          uses: redjax/PipelineTemplates/.github/actions/notify-ntfy@v0.0.1
          with:
            ntfy-server: https://ntfy.example.com
            topic: ci-builds
            title: "CI summary"
            # Multi-line rich message using raw-body
            raw-body: |
              ## CI summary

              - Workflow: ${{ github.workflow }}
              - Run: ${{ github.run_number }}
              - Status: ${{ job.status }}
              - Commit: ${{ github.sha }}

              View details: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
            priority: "default"
            tags: "github,ci,summary"
            click-url: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
            auth-token: ${{ secrets.NTFY_TOKEN }}
  ```

- Attach an external artifact (report, screenshot, etc.)

  ```yaml
  jobs:
    notify:
      runs-on: ubuntu-latest
      steps:
        - name: Publish artifacts
          uses: actions/upload-artifact@v4
          with:
            name: test-report
            path: path/to/report.html

        - name: Notify via ntfy with attachment
          uses: redjax/PipelineTemplates/.github/actions/notify-ntfy@v0.0.1
          with:
            ntfy-server: https://ntfy.example.com
            topic: ci-builds
            title: "Tests completed"
            message: "Test report for run ${{ github.run_number }} is available."
            priority: "default"
            tags: "github,ci,tests"
            click-url: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
            # Link to wherever your report is hosted (e.g. static site, artifact proxy)
            attach: "https://artifacts.example.com/reports/${{ github.run_id }}/report.html"
            auth-token: ${{ secrets.NTFY_TOKEN }}
  ```
