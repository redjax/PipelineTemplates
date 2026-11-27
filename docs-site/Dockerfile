# syntax=docker/dockerfile:1@sha256:572cebbc2b15e6f84c077742952674889cb63cd5e9b80abdffcbe587b6f19183

ARG PYTHON_IMG_TAG=3.15-slim@sha256:63bb298d2b7b88f176f51b5189f54ce6535c997682ea70885d2132f5d473a8a5
ARG UV_IMG_TAG=0.13.5
ARG NGINX_IMG_TAG=1.31-alpine@sha256:b5047b9b76845eac124358373c6852377c52e4b05834a47647e955dd91cb8f1e

FROM ghcr.io/astral-sh/uv:${UV_IMG_TAG} AS uv

FROM python:${PYTHON_IMG_TAG} AS base

COPY --from=uv /uv /uvx /bin/

WORKDIR /workspace

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

FROM base AS stage

COPY docs-site/pyproject.toml docs-site/uv.lock docs-site/

WORKDIR /workspace/docs-site

RUN uv sync --locked

FROM stage AS dev

WORKDIR /workspace

ENV PATH="/workspace/docs-site/.venv/bin:$PATH"

EXPOSE 8118

CMD ["zensical", "serve", "--dev-addr", "0.0.0.0:8118"]

FROM base AS build

WORKDIR /workspace

COPY docs-site/pyproject.toml docs-site/uv.lock docs-site/

RUN uv sync \
  --locked \
  --project /workspace/docs-site

COPY . .

RUN uv run \
  --project /workspace/docs-site \
  zensical build \
  --config-file /workspace/zensical.toml

FROM nginxinc/nginx-unprivileged:${NGINX_IMG_TAG} AS prod

COPY --from=build /workspace/docs-site/site /usr/share/nginx/html

USER 101:101

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
