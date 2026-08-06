# syntax=docker/dockerfile:1.7

FROM node:24.13.1-alpine3.22 AS builder

ARG GIT_SHA=development
ARG VITE_API_BASE_URL

WORKDIR /build

COPY .npmrc package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci

COPY index.html tsconfig.json tsconfig.app.json tsconfig.node.json vite.config.ts ./
COPY public ./public
COPY src ./src

RUN VITE_GIT_SHA="${GIT_SHA}" VITE_API_BASE_URL="${VITE_API_BASE_URL}" npm run build

FROM nginxinc/nginx-unprivileged:1.29.4-alpine3.23 AS runtime

ARG BUILD_VERSION=0.1.0
ARG GIT_SHA=development

USER 0

RUN apk upgrade --no-cache libcrypto3 libssl3

USER 101:101

LABEL org.opencontainers.image.title="Northstar Supply Storefront" \
      org.opencontainers.image.description="React storefront for the Azure SRE Agent demo" \
      org.opencontainers.image.version="${BUILD_VERSION}" \
      org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.source="https://github.com/msftse/sre-agent-demo"

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder --chown=101:101 /build/dist /usr/share/nginx/html

USER 101:101

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["wget", "-q", "-O", "/dev/null", "http://127.0.0.1:8080/healthz"]
