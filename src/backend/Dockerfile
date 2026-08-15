# syntax=docker/dockerfile:1.7

FROM python:3.12.13-slim-bookworm AS builder

ENV PIP_CONFIG_FILE=/build/pip.conf \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /build

COPY pip.conf pyproject.toml ./
COPY app ./app

RUN python -m venv /opt/venv \
    && /opt/venv/bin/pip install .

FROM python:3.12.13-slim-bookworm AS runtime

ARG BUILD_VERSION=0.1.0
ARG GIT_SHA=development
ARG SOURCE_REPOSITORY_URL

LABEL org.opencontainers.image.title="Northstar Supply API" \
      org.opencontainers.image.description="FastAPI checkout service for the Azure SRE Agent demo" \
      org.opencontainers.image.version="${BUILD_VERSION}" \
      org.opencontainers.image.revision="${GIT_SHA}" \
    org.opencontainers.image.source="${SOURCE_REPOSITORY_URL}"

ENV PATH=/opt/venv/bin:${PATH} \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    SRE_DEMO_ENVIRONMENT=container \
    SRE_DEMO_GIT_SHA=${GIT_SHA} \
    SRE_DEMO_IMAGE_DIGEST=local-image \
    SRE_DEMO_SERVICE_VERSION=${BUILD_VERSION}

RUN groupadd --gid 10001 app \
    && useradd --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app

WORKDIR /app

COPY --from=builder --chown=10001:10001 /opt/venv /opt/venv

USER 10001:10001

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health/live', timeout=2)"]

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--no-access-log", "--proxy-headers", "--forwarded-allow-ips=*"]
