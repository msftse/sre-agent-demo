import json
import logging

from fastapi.testclient import TestClient
from opentelemetry.sdk.trace.export.in_memory_span_exporter import InMemorySpanExporter

from app.main import create_app
from app.observability import JsonFormatter


def test_release_identity_and_prometheus_metrics() -> None:
    application = create_app()
    with TestClient(application) as client:
        release = client.get("/api/release")
        products = client.get("/api/products", headers={"x-operation-id": "review-operation"})
        metrics = client.get("/metrics")

    assert release.json()["git_sha"] == "development"
    assert products.headers["x-operation-id"] == "review-operation"
    assert products.headers["x-build-sha"] == "development"
    assert len(products.headers["x-trace-id"]) == 32
    assert 'northstar_build_info{environment="local",git_sha="development"' in metrics.text
    assert 'route="/api/products",status_code="200"' in metrics.text
    assert "northstar_http_request_duration_seconds_bucket" in metrics.text
    assert "northstar_http_requests_in_progress 0.0" in metrics.text


def test_checkout_metrics_and_trace_spans() -> None:
    exporter = InMemorySpanExporter()
    application = create_app(span_exporter=exporter)
    trace_id = "1234567890abcdef1234567890abcdef"
    with TestClient(application) as client:
        response = client.post(
            "/api/checkout",
            headers={"traceparent": f"00-{trace_id}-1234567890abcdef-01"},
            json={
                "email": "explorer@example.com",
                "items": [{"product_id": "field-pack-28", "quantity": 1}],
            },
        )
        rejected = client.post(
            "/api/checkout",
            json={
                "email": "explorer@example.com",
                "discount_code": "NOT-A-CODE",
                "items": [{"product_id": "field-pack-28", "quantity": 1}],
            },
        )
        metrics = client.get("/metrics")

    spans = exporter.get_finished_spans()
    assert response.status_code == 200
    assert rejected.status_code == 422
    assert response.headers["x-trace-id"] == trace_id
    assert 'northstar_checkout_attempts_total{outcome="confirmed"} 1.0' in metrics.text
    assert 'northstar_checkout_attempts_total{outcome="rejected"} 1.0' in metrics.text
    assert {span.name for span in spans} >= {"POST /api/checkout", "checkout.calculate"}
    confirmed_spans = [span for span in spans if f"{span.context.trace_id:032x}" == trace_id]
    assert {span.name for span in confirmed_spans} == {
        "POST /api/checkout",
        "checkout.calculate",
    }
    rejected_checkout = next(
        span
        for span in spans
        if span.name == "checkout.calculate" and span.status.status_code.name == "ERROR"
    )
    exception_event = next(event for event in rejected_checkout.events if event.name == "exception")
    assert exception_event.attributes is not None
    assert exception_event.attributes["exception.message"] == "That code is not active."


def test_json_formatter_includes_correlation_and_release_fields() -> None:
    record = logging.LogRecord(
        name="northstar.api",
        level=logging.INFO,
        pathname=__file__,
        lineno=1,
        msg="request_completed",
        args=(),
        exc_info=None,
    )
    record.operation_id = "operation-123"
    record.trace_id = "a" * 32
    record.git_sha = "commit-abc"
    record.status_code = 200

    payload = json.loads(JsonFormatter().format(record))

    assert payload["message"] == "request_completed"
    assert payload["operation_id"] == "operation-123"
    assert payload["trace_id"] == "a" * 32
    assert payload["git_sha"] == "commit-abc"
    assert payload["status_code"] == 200