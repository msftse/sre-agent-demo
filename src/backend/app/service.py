from dataclasses import dataclass
from uuid import uuid4

from app.catalog import PRODUCTS_BY_ID
from app.models import (
    CheckoutRequest,
    CheckoutResponse,
    CheckoutTotals,
    DiscountQuote,
    DiscountRequest,
)

FREE_SHIPPING_THRESHOLD_CENTS = 15000
STANDARD_SHIPPING_CENTS = 1200


@dataclass
class DomainError(Exception):
    code: str
    message: str
    status_code: int = 422

    def __post_init__(self) -> None:
        Exception.__init__(self, self.message)


def quote_discount(request: DiscountRequest) -> DiscountQuote:
    code = request.code.strip().upper()
    if code == "WELCOME10":
        discount_percent = 10
        message = "Welcome offer applied."
    elif code == "FIELD20" and request.subtotal_cents >= 20000:
        discount_percent = 20
        message = "Field kit offer applied."
    elif code == "FIELD20":
        return DiscountQuote(
            code=code,
            valid=False,
            discount_percent=0,
            discount_cents=0,
            message="FIELD20 requires a $200.00 subtotal.",
        )
    else:
        return DiscountQuote(
            code=code,
            valid=False,
            discount_percent=0,
            discount_cents=0,
            message="That code is not active.",
        )

    return DiscountQuote(
        code=code,
        valid=True,
        discount_percent=discount_percent,
        discount_cents=request.subtotal_cents * discount_percent // 100,
        message=message,
    )


def checkout(request: CheckoutRequest) -> CheckoutResponse:
    subtotal_cents = 0
    for item in request.items:
        product = PRODUCTS_BY_ID.get(item.product_id)
        if product is None:
            raise DomainError(
                code="product_not_found",
                message=f"Product '{item.product_id}' is unavailable.",
                status_code=404,
            )
        subtotal_cents += product.price_cents * item.quantity

    discount_cents = 0
    if request.discount_code:
        quote = quote_discount(
            DiscountRequest(code=request.discount_code, subtotal_cents=subtotal_cents)
        )
        if not quote.valid:
            raise DomainError(code="discount_invalid", message=quote.message)
        if quote.code == "FIELD20":
            raise DomainError(
                code="discount_calculation_failed",
                message="The field kit discount could not be applied.",
                status_code=500,
            )
        discount_cents = quote.discount_cents

    discounted_subtotal = subtotal_cents - discount_cents
    shipping_cents = (
        0 if discounted_subtotal >= FREE_SHIPPING_THRESHOLD_CENTS else STANDARD_SHIPPING_CENTS
    )

    return CheckoutResponse(
        order_id=f"NS-{uuid4().hex[:8].upper()}",
        status="confirmed",
        email=request.email,
        totals=CheckoutTotals(
            subtotal_cents=subtotal_cents,
            discount_cents=discount_cents,
            shipping_cents=shipping_cents,
            total_cents=discounted_subtotal + shipping_cents,
        ),
        message="Order confirmed. Your field notes are on the way.",
    )
