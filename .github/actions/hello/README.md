# DEMO Github Action: hello

This Action is a simple "demo" module. It is the first component created in this repository, all it does is echo a configurable message (default: `"hello from pipeline templates"`). The Action serves as a demo for versioning/calling from an external repository.

## Inputs

- `message`: The message the pipeline should print

## Usage

In the calling repository, create a pipeline, i.e. `.github/workflows/print-message.yml`. Expose a `message` input in the calling repository, then pass it into the Action call:

```yaml
---
name: Test hello-world demo

on:
  workflow_dispatch:
    inputs:
      message:
        description: The message to print
        required: false
        type: string
        default: Hello from PipelineTemplates-test

jobs:
  call-template:
    runs-on: ubuntu-latest
    steps:
      - name: Print message
        uses: redjax/PipelineTemplates/.github/actions/hello@gh/hello/v0.0.1
        with:
          message: ${{ inputs.message }}
```
