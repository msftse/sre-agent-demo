from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from opentelemetry.sdk.trace.export import SpanExporter
from starlette.middleware.base import RequestResponseEndpoint

from app.catalog import PRODUCTS
from app.config import get_settings
from app.models import (
    CheckoutRequest,
    CheckoutResponse,
    DiscountQuote,
    DiscountRequest,
    ErrorDetail,
    HealthResponse,
    Product,
    ReleaseInfo,
)
from app.observability import Telemetry, configure_logger, observe_request
from app.service import DomainError, checkout, quote_discount


@asynccontextmanager
async def lifespan(application: FastAPI) -> AsyncIterator[None]:
    get_settings.cache_clear()
    yield
    application.state.telemetry.shutdown()


def create_app(span_exporter: SpanExporter | None = None) -> FastAPI:
    settings = get_settings()
    telemetry = Telemetry(settings, span_exporter=span_exporter)
    logger = configure_logger(settings)
    application = FastAPI(
        title=settings.app_name,
        version="0.1.0",
        lifespan=lifespan,
        docs_url="/docs",
        redoc_url=None,
    )
    application.state.telemetry = telemetry
    application.state.logger = logger
    application.add_middleware(
        CORSMiddleware,
        allow_origins=list(settings.allowed_origins),
        allow_credentials=False,
        allow_methods=["GET", "POST"],
        allow_headers=["Content-Type"],
        expose_headers=["X-Build-SHA", "X-Operation-ID", "X-Trace-ID"],
    )

    @application.middleware("http")
    async def telemetry_middleware(
        request: Request, call_next: RequestResponseEndpoint
    ) -> Response:
        return await observe_request(request, call_next, telemetry, logger)

    @application.exception_handler(DomainError)
    async def handle_domain_error(request: Request, error: DomainError) -> JSONResponse:
        detail = ErrorDetail(code=error.code, message=error.message)
        logger.warning(
            "domain_error",
            extra={
                **telemetry.release_log_fields(),
                **telemetry.trace_fields(),
                "operation_id": request.state.operation_id,
                "error_code": error.code,
                "status_code": error.status_code,
            },
        )
        return JSONResponse(status_code=error.status_code, content={"detail": detail.model_dump()})

    @application.get("/health/live", response_model=HealthResponse, tags=["health"])
    async def live() -> HealthResponse:
        return HealthResponse(
            status="ok",
            service=settings.app_name,
            environment=settings.environment,
        )

    @application.get("/health/ready", response_model=HealthResponse, tags=["health"])
    async def ready() -> HealthResponse:
        return HealthResponse(
            status="ready",
            service=settings.app_name,
            environment=settings.environment,
        )

    @application.get("/api/release", response_model=ReleaseInfo, tags=["metadata"])
    async def release() -> ReleaseInfo:
        return ReleaseInfo(
            service=settings.app_name,
            version=settings.service_version,
            environment=settings.environment,
            git_sha=settings.git_sha,
            image_digest=settings.image_digest,
            instance_id=settings.instance_id,
        )

    @application.get("/metrics", include_in_schema=False)
    async def metrics() -> Response:
        return telemetry.metrics_response()

    @application.get("/api/products", response_model=list[Product], tags=["catalogue"])
    async def products() -> tuple[Product, ...]:
        return PRODUCTS

    @application.post(
        "/api/discounts/validate",
        response_model=DiscountQuote,
        tags=["checkout"],
    )
    async def validate_discount(request: DiscountRequest) -> DiscountQuote:
        return quote_discount(request)

    @application.post(
        "/api/checkout",
        response_model=CheckoutResponse,
        responses={404: {"model": ErrorDetail}, 422: {"model": ErrorDetail}},
        tags=["checkout"],
    )
    async def create_checkout(request: CheckoutRequest) -> CheckoutResponse:
        discount_code = (request.discount_code or "").strip().upper()
        with telemetry.tracer.start_as_current_span(
            "checkout.calculate",
            attributes={
                "checkout.item_types": len(request.items),
                "checkout.discount_requested": request.discount_code is not None,
                "checkout.discount_code": (
                    "FIELD20" if discount_code == "FIELD20" else "other"
                ),
            },
        ):
            try:
                response = checkout(request)
            except DomainError:
                telemetry.checkout_attempts.labels(outcome="rejected").inc()
                raise
            telemetry.checkout_attempts.labels(outcome="confirmed").inc()
            return response

    return application


app = create_app()
