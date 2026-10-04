# syntax=docker/dockerfile:1

ARG PYTHON_IMG_TAG=3.14-slim
ARG UV_IMG_TAG=0.12.23
ARG NGINX_IMG_TAG=1.31-alpine

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
