# Stage 2: Healthy Backend and Frontend

## Goal

Build the healthy application that later becomes the subject of the incident demonstration. This stage establishes the API contract and storefront behavior without observability, containers, Kubernetes, Azure resources, or a deliberate defect.

## Source Layout

All application code is grouped under `src/`:

- `src/backend` contains the Python 3.12 FastAPI service, domain logic, dependency lock, and API tests.
- `src/frontend` contains the React and TypeScript storefront, API client, styles, behavior tests, and npm lock.

## Backend

The backend owns product pricing and checkout decisions. It provides:

- Synthetic product catalogue data with stable identifiers.
- Quantities constrained to 1-10 units per item.
- `WELCOME10` and thresholded `FIELD20` discount behavior.
- Server-side subtotal, discount, shipping, and total calculation.
- Structured domain errors for missing products and invalid discounts.
- Liveness and readiness endpoints for future Kubernetes probes.
- CORS restricted by configuration, with the local Vite origin allowed by default.

## Frontend

Northstar Supply is a responsive field-equipment storefront with:

- Server-loaded catalogue and explicit loading/failure states.
- Stable product cards and accessible quantity controls.
- Server-validated discount feedback.
- Cart totals and free-shipping threshold display.
- Email validation and healthy checkout confirmation.
- Keyboard focus treatment, reduced-motion support, descriptive images, and mobile layout.
- A restrained forest, paper, and safety-orange visual language appropriate to an operational demonstration.

## Package Sources

Dependencies use only the requested Microsoft proxies:

- npm: `https://packagefeedproxy.microsoft.io/npm/`
- Python: `https://packagefeedproxy.microsoft.io/pypi/simple`

`uv.lock` records the Microsoft Python proxy. npm resolves tarballs through the proxy's internal Azure DevOps feeds and the lockfile contains no `registry.npmjs.org` URL.

## Validation

Backend:

```text
Ruff:  passed
mypy:  passed in 7 source files
pytest: 7 passed
coverage: 97.92% (95% minimum)
Python: 3.12.13
```

Frontend:

```text
Vitest: 3 passed
ESLint: passed
TypeScript production build: passed
npm audit --omit=dev: 0 vulnerabilities
```

The tests cover catalogue retrieval, discount normalization and thresholds, server repricing, checkout confirmation, invalid products, invalid discounts, invalid requests, catalogue rendering, adding to cart, discount application, and checkout confirmation.

## Outcome

Stage 2 passed. Stage 3 will run both services locally and keep them available while the user reviews the complete desktop and mobile experience.