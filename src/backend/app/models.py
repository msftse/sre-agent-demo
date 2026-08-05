from typing import Annotated, Literal

from pydantic import BaseModel, EmailStr, Field

PositiveQuantity = Annotated[int, Field(ge=1, le=10)]


class Product(BaseModel):
    id: str
    name: str
    category: str
    description: str
    price_cents: int = Field(ge=0)
    image_url: str
    image_alt: str
    accent: str
    badge: str | None = None


class CartItem(BaseModel):
    product_id: str
    quantity: PositiveQuantity


class DiscountRequest(BaseModel):
    code: str = Field(min_length=1, max_length=32)
    subtotal_cents: int = Field(ge=0)


class DiscountQuote(BaseModel):
    code: str
    valid: bool
    discount_percent: int = Field(ge=0, le=100)
    discount_cents: int = Field(ge=0)
    message: str


class CheckoutRequest(BaseModel):
    email: EmailStr
    items: list[CartItem] = Field(min_length=1, max_length=20)
    discount_code: str | None = Field(default=None, max_length=32)


class CheckoutTotals(BaseModel):
    subtotal_cents: int = Field(ge=0)
    discount_cents: int = Field(ge=0)
    shipping_cents: int = Field(ge=0)
    total_cents: int = Field(ge=0)


class CheckoutResponse(BaseModel):
    order_id: str
    status: Literal["confirmed"]
    email: EmailStr
    totals: CheckoutTotals
    message: str


class HealthResponse(BaseModel):
    status: Literal["ok", "ready"]
    service: str
    environment: str


class ErrorDetail(BaseModel):
    code: str
    message: str
