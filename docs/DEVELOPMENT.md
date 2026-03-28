# PipelineTemplates - Development <!-- omit in toc -->

## Table of Contents <!-- omit in toc -->

## Overview

- Github Actions must be in `.github/workflows/` dir
- The [`manifests/version.yml` file](../manifests/versions.yml) tracks each pipeline's current version
- The [`manual-release.sh` script](../.scripts/manual-release.sh) (will) detect each pipeline for individual and automated versioning
- A pipeline (will) automatically bump versions on merges to the `main` branch
