import json
import logging
import sys
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime
from time import perf_counter
from typing import Any
from uuid import uuid4

from fastapi import Request, Response
from opentelemetry import propagate
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import (
    ConsoleSpanExporter,
    SimpleSpanProcessor,
    SpanExporter,
)
from opentelemetry.trace import SpanKind, Status, StatusCode
from prometheus_client import CollectorRegistry, Counter, Gauge, Histogram, generate_latest
from prometheus_client.exposition import CONTENT_TYPE_LATEST

from app.config import Settings

CallNext = Callable[[Request], Awaitable[Response]]


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "timestamp": datetime.fromtimestamp(record.created, UTC).isoformat(),
            "level": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
        }
        for field in (
            "service",
            "environment",
            "version",
            "git_sha",
            "image_digest",
            "instance_id",
            "operation_id",
            "trace_id",
            "span_id",
            "method",
            "route",
            "status_code",
            "duration_ms",
            "error_code",
        ):
            value = getattr(record, field, None)
            if value is not None:
                payload[field] = value
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        return json.dumps(payload, separators=(",", ":"), sort_keys=True)


def configure_logger(settings: Settings) -> logging.Logger:
    logger = logging.getLogger("northstar.api")
    logger.handlers.clear()
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter())
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)
    logger.propagate = False
    return logger


class Telemetry:
    def __init__(self, settings: Settings, span_exporter: SpanExporter | None = None) -> None:
        self.settings = settings
        self.registry = CollectorRegistry(auto_describe=True)
        self.http_requests = Counter(
            "northstar_http_requests",
            "Completed HTTP requests.",
            ("method", "route", "status_code"),
            registry=self.registry,
        )
        self.http_request_duration = Histogram(
            "northstar_http_request_duration_seconds",
            "HTTP request duration in seconds.",
            ("method", "route"),
            buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0),
            registry=self.registry,
        )
        self.http_requests_in_progress = Gauge(
            "northstar_http_requests_in_progress",
            "HTTP requests currently in progress.",
            registry=self.registry,
        )
        self.checkout_attempts = Counter(
            "northstar_checkout_attempts",
            "Checkout attempts by bounded outcome.",
            ("outcome",),
            registry=self.registry,
        )
        self.build_info = Gauge(
            "northstar_build_info",
            "Immutable release identity for the running service.",
            ("version", "git_sha", "image_digest", "environment"),
            registry=self.registry,
        )
        self.build_info.labels(
            version=settings.service_version,
            git_sha=settings.git_sha,
            image_digest=settings.image_digest,
            environment=settings.environment,
        ).set(1)

        self.tracer_provider = TracerProvider(
            resource=Resource.create(
                {
                    "service.name": settings.app_name,
                    "service.version": settings.service_version,
                    "service.instance.id": settings.instance_id,
                    "deployment.environment.name": settings.environment,
                }
            )
        )
        exporter = span_exporter
        if exporter is None and settings.trace_console_exporter:
            exporter = ConsoleSpanExporter()
        if exporter is not None:
            self.tracer_provider.add_span_processor(SimpleSpanProcessor(exporter))
        self.tracer = self.tracer_provider.get_tracer("northstar.api", settings.service_version)

    def metrics_response(self) -> Response:
        return Response(content=generate_latest(self.registry), media_type=CONTENT_TYPE_LATEST)

    def trace_fields(self) -> dict[str, str]:
        from opentelemetry import trace

        context = trace.get_current_span().get_span_context()
        if not context.is_valid:
            return {"trace_id": "", "span_id": ""}
        return {
            "trace_id": f"{context.trace_id:032x}",
            "span_id": f"{context.span_id:016x}",
        }

    def release_log_fields(self) -> dict[str, str]:
        return {
            "service": self.settings.app_name,
            "environment": self.settings.environment,
            "version": self.settings.service_version,
            "git_sha": self.settings.git_sha,
            "image_digest": self.settings.image_digest,
            "instance_id": self.settings.instance_id,
        }

    def shutdown(self) -> None:
        self.tracer_provider.shutdown()


def route_template(request: Request) -> str:
    route = request.scope.get("route")
    path = getattr(route, "path", None)
    return path if isinstance(path, str) else "unmatched"


async def observe_request(
    request: Request,
    call_next: CallNext,
    telemetry: Telemetry,
    logger: logging.Logger,
) -> Response:
    if request.url.path == "/metrics":
        return await call_next(request)

    operation_id = request.headers.get("x-operation-id", "")[:128] or str(uuid4())
    request.state.operation_id = operation_id
    method = request.method
    started = perf_counter()
    status_code = 500
    response: Response | None = None
    extracted_context = propagate.extract(dict(request.headers))

    telemetry.http_requests_in_progress.inc()
    try:
        with telemetry.tracer.start_as_current_span(
            f"{method} {request.url.path}",
            context=extracted_context,
            kind=SpanKind.SERVER,
            attributes={
                "http.request.method": method,
                "url.path": request.url.path,
                "operation.id": operation_id,
                "service.git_sha": telemetry.settings.git_sha,
            },
        ) as span:
            try:
                response = await call_next(request)
                status_code = response.status_code
            except Exception as error:
                span.record_exception(error)
                span.set_status(Status(StatusCode.ERROR, str(error)))
                raise
            finally:
                route = route_template(request)
                duration_seconds = perf_counter() - started
                span.update_name(f"{method} {route}")
                span.set_attribute("http.route", route)
                span.set_attribute("http.response.status_code", status_code)
                trace_fields = telemetry.trace_fields()
                telemetry.http_requests.labels(
                    method=method,
                    route=route,
                    status_code=str(status_code),
                ).inc()
                telemetry.http_request_duration.labels(method=method, route=route).observe(
                    duration_seconds
                )
                logger.info(
                    "request_completed",
                    extra={
                        **telemetry.release_log_fields(),
                        **trace_fields,
                        "operation_id": operation_id,
                        "method": method,
                        "route": route,
                        "status_code": status_code,
                        "duration_ms": round(duration_seconds * 1000, 3),
                    },
                )

            if response is not None:
                response.headers["x-operation-id"] = operation_id
                response.headers["x-trace-id"] = telemetry.trace_fields()["trace_id"]
                response.headers["x-build-sha"] = telemetry.settings.git_sha
                return response
    finally:
        telemetry.http_requests_in_progress.dec()

    raise RuntimeError("Request middleware completed without a response")