from app.models import Product

PRODUCTS: tuple[Product, ...] = (
    Product(
        id="field-pack-28",
        name="Field Pack 28",
        category="Carry",
        description="Weather-ready day pack with a structured back panel and quick-access lid.",
        price_cents=14800,
        image_url="/products/field-pack.jpg",
        image_alt="Olive technical backpack resting on a concrete ledge",
        accent="#315c4c",
        badge="Field tested",
    ),
    Product(
        id="alpine-shell",
        name="Alpine Shell",
        category="Outerwear",
        description="Three-layer storm shell cut for movement, with fully taped seams.",
        price_cents=22600,
        image_url="/products/alpine-shell.jpg",
        image_alt="Hiker wearing a bright technical shell in a mountain landscape",
        accent="#d9603b",
        badge="New season",
    ),
    Product(
        id="trail-flask",
        name="Trail Flask 750",
        category="Hydration",
        description="Double-wall steel flask with a glove-friendly cap and carry loop.",
        price_cents=4200,
        image_url="/products/trail-flask.jpg",
        image_alt="Reusable metal water bottle outdoors",
        accent="#d7a928",
    ),
    Product(
        id="ridge-lamp",
        name="Ridge Lamp 400",
        category="Camp",
        description="Rechargeable warm-light lantern with a low-glare night setting.",
        price_cents=6800,
        image_url="/products/ridge-lamp.jpg",
        image_alt="Warm camp lantern glowing beside a tent",
        accent="#246b75",
        badge="Staff pick",
    ),
)

PRODUCTS_BY_ID = {product.id: product for product in PRODUCTS}
