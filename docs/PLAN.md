# PipelineTemplates - Plan

A rough outline of the desired end state for this repository.

## High level

- [ ] Support multiple pipeline tools
  - [ ] Github Actions
  - [ ] Gitlab
  - [ ] Codeberg/Forgejo
  - [ ] Woodpecker CI
  - [ ] Concourse CI
- [ ] Tag/version each individual pipeline
  - [ ] CI automation in this repository that detects all templates in each parent dir, then detects any changes made to those files, to automatically version bump in the verions manifest file
