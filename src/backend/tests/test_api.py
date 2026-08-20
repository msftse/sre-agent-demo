from fastapi.testclient import TestClient

from app.main import app


def test_health_endpoints() -> None:
    with TestClient(app) as client:
        live_response = client.get("/health/live")
        ready_response = client.get("/health/ready")

    assert live_response.status_code == 200
    assert live_response.json()["status"] == "ok"
    assert ready_response.status_code == 200
    assert ready_response.json()["status"] == "ready"


def test_local_frontend_cors_preflight() -> None:
    with TestClient(app) as client:
        preflight = client.options(
            "/api/products",
            headers={
                "Origin": "http://127.0.0.1:5173",
                "Access-Control-Request-Method": "GET",
            },
        )
        response = client.get(
            "/api/products",
            headers={"Origin": "http://127.0.0.1:5173"},
        )

    assert preflight.status_code == 200
    assert preflight.headers["access-control-allow-origin"] == "http://127.0.0.1:5173"
    assert response.status_code == 200
    assert response.headers["access-control-expose-headers"] == (
        "X-Build-SHA, X-Operation-ID, X-Trace-ID"
    )


def test_catalogue_returns_server_priced_products() -> None:
    with TestClient(app) as client:
        response = client.get("/api/products")

    products = response.json()
    assert response.status_code == 200
    assert len(products) == 4
    assert products[0]["id"] == "field-pack-28"
    assert products[0]["price_cents"] == 14800
    assert all(product["image_url"].startswith("/products/") for product in products)


def test_discount_codes_are_normalized_and_thresholded() -> None:
    with TestClient(app) as client:
        welcome = client.post(
            "/api/discounts/validate",
            json={"code": " welcome10 ", "subtotal_cents": 14800},
        )
        field_too_small = client.post(
            "/api/discounts/validate",
            json={"code": "FIELD20", "subtotal_cents": 19999},
        )

    assert welcome.json() == {
        "code": "WELCOME10",
        "valid": True,
        "discount_percent": 10,
        "discount_cents": 1480,
        "message": "Welcome offer applied.",
    }
    assert field_too_small.json()["valid"] is False
    assert "$200.00" in field_too_small.json()["message"]


def test_checkout_reprices_items_and_applies_free_shipping() -> None:
    with TestClient(app) as client:
        response = client.post(
            "/api/checkout",
            json={
                "email": "explorer@example.com",
                "discount_code": "WELCOME10",
                "items": [
                    {"product_id": "field-pack-28", "quantity": 1},
                    {"product_id": "trail-flask", "quantity": 1},
                ],
            },
        )

    body = response.json()
    assert response.status_code == 200
    assert body["status"] == "confirmed"
    assert body["order_id"].startswith("NS-")
    assert body["totals"] == {
        "subtotal_cents": 19000,
        "discount_cents": 1900,
        "shipping_cents": 0,
        "total_cents": 17100,
    }


def test_checkout_rejects_unknown_product() -> None:
    with TestClient(app) as client:
        response = client.post(
            "/api/checkout",
            json={
                "email": "explorer@example.com",
                "items": [{"product_id": "missing", "quantity": 1}],
            },
        )

    assert response.status_code == 404
    assert response.json()["detail"]["code"] == "product_not_found"


def test_checkout_rejects_invalid_discount() -> None:
    with TestClient(app) as client:
        response = client.post(
            "/api/checkout",
            json={
                "email": "explorer@example.com",
                "discount_code": "NOT-A-CODE",
                "items": [{"product_id": "ridge-lamp", "quantity": 1}],
            },
        )

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "discount_invalid"


def test_checkout_validates_empty_cart_and_email() -> None:
    with TestClient(app) as client:
        response = client.post(
            "/api/checkout",
            json={"email": "not-an-email", "items": []},
        )

    assert response.status_code == 422
    error_locations = {tuple(error["loc"]) for error in response.json()["detail"]}
    assert ("body", "email") in error_locations
    assert ("body", "items") in error_locations


def test_checkout_applies_field20_to_qualifying_order() -> None:
    with TestClient(app) as client:
        response = client.post(
            "/api/checkout",
            json={
                "email": "explorer@example.com",
                "discount_code": "FIELD20",
                "items": [
                    {"product_id": "field-pack-28", "quantity": 2},
                ],
            },
        )

    body = response.json()
    assert response.status_code == 200
    assert body["status"] == "confirmed"
    assert body["totals"] == {
        "subtotal_cents": 29600,
        "discount_cents": 5920,
        "shipping_cents": 0,
        "total_cents": 23680,
    }
