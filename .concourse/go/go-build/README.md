# Concourse - Go Build

Re-usable Concourse CI components for building, testing, and publishing a Go app.

## Usage

Copy one of the [example pipelines](./examples/) into a repository with a Go application. You can replace `((variables))` with hardcoded values specific to your app, or set environment/pipeline variables & secrets to modify the pipeline's behavior.

For example, pretend you have a repository with a Go module/package named `generic-restapi`. You want to build and test the Go application in a pipeline.

Create a pipeline file, i.e. `.concourse/build-go-app.yml`:

```yaml
---
resources:
  - name: pipelinetemplates
    type: git
    source:
      uri: git@github.com:redjax/pipelinetemplates.git
      branch: main

  - name: app
    type: git
    source:
      uri: git@github.com:redjax/generic-restapi.git
      branch: main

  - name: go-image
    type: registry-image
    source:
      repository: golang
      tag: 1.26.4

jobs:
  - name: build-generic-restapi
    public: true
    plan:
      - get: pipelinetemplates
        trigger: true
      - get: app
        trigger: true
      - get: go-image

      - task: build
        image: go-image
        file: pipelinetemplates/.concourse/go/go-build/tasks/build.yml
        params:
          MODULE_DIR: .
          BUILD_PACKAGE: ./...
          BINARY_NAME: generic-restapi
          PLATFORMS: linux/amd64
          BUILD_TAGS: ""
          LDFLAGS: ""
          OUTPUT_DIR: dist
          CGO_ENABLED: 0

      - task: test
        image: go-image
        file: pipelinetemplates/.concourse/go/go-build/tasks/test.yml
        params:
          MODULE_DIR: .
          TEST_PACKAGE: ./...
          TEST_FLAGS: ""
          CGO_ENABLED: 0
```

An example vars file is provided in [`vars/default.yml`](./vars/default.yml).

You can copy it into your app repository and update the values for that app, or you can hardcode the values directly in your pipeline file.

Set the pipeline with `fly`:

```bash
fly -t <concourse-target> set-pipeline \
  -p build-generic-restapi \
  -c .concourse/build-go-app.yml \
  -l .concourse/vars/build-go-app.yml
```

Then unpause it:

```bash
fly -t <concourse-target> unpause-pipeline -p build-generic-restapi
```
