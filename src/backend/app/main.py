from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

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
)
from app.service import DomainError, checkout, quote_discount


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    get_settings.cache_clear()
    yield


def create_app() -> FastAPI:
    settings = get_settings()
    application = FastAPI(
        title=settings.app_name,
        version="0.1.0",
        lifespan=lifespan,
        docs_url="/docs",
        redoc_url=None,
    )
    application.add_middleware(
        CORSMiddleware,
        allow_origins=list(settings.allowed_origins),
        allow_credentials=False,
        allow_methods=["GET", "POST"],
        allow_headers=["Content-Type"],
    )

    @application.exception_handler(DomainError)
    async def handle_domain_error(_: Request, error: DomainError) -> JSONResponse:
        detail = ErrorDetail(code=error.code, message=error.message)
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
        return checkout(request)

    return application


app = create_app()
