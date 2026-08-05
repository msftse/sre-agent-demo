# Stage 3: Local Application Review

## Goal

Run the backend and frontend together, validate the real browser-to-API path, and pause for human review before adding observability, containers, Kubernetes, or Azure infrastructure.

## Run Locally

Start the backend:

```bash
cd src/backend
uv run uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Start the frontend in a second terminal:

```bash
cd src/frontend
npm run dev -- --host 127.0.0.1 --port 5173 --strictPort
```

Review endpoints:

| Experience | URL |
| --- | --- |
| Storefront | `http://127.0.0.1:5173/` |
| OpenAPI documentation | `http://127.0.0.1:8000/docs` |
| Liveness | `http://127.0.0.1:8000/health/live` |
| Readiness | `http://127.0.0.1:8000/health/ready` |

## Findings and Repairs

### Loopback CORS

The first browser run exposed a hostname mismatch: Vite was intentionally bound to `127.0.0.1`, while the backend allowed only `localhost:5173`. The backend now permits both loopback forms, and the API suite verifies that the `127.0.0.1` OPTIONS preflight returns the matching `Access-Control-Allow-Origin` header.

### Deterministic Images

One external Unsplash response was blocked by browser cross-origin response protection. All four product photographs are now static files under `src/frontend/public/products`, and the API returns same-origin `/products/...` paths. This makes local review and later AKS deployment independent of third-party image availability.

Image source identifiers retained from the original catalogue:

- Field Pack: Unsplash photo `1553062407-98eeb64c6a62`
- Alpine Shell: Unsplash photo `1551632811-561732d1e306`
- Trail Flask: Unsplash photo `1602143407151-7111542de6e8`
- Ridge Lamp: Unsplash photo `1523987355523-c7b5b0dd90a7`

## Browser Validation

Desktop validation at 1440 by 1000 pixels proved:

- Four catalogue products and all four local images loaded.
- Two-item checkout subtotaled to `$190.00`.
- `WELCOME10` produced a `$19.00` discount and `$171.00` confirmed total.
- No horizontal overflow occurred.

Mobile validation at 390 by 844 pixels proved:

- The order panel appears before the catalogue for an efficient checkout workflow.
- Quantity controls, discount input, checkout input, and buttons fit the viewport.
- Invalid code `NOT-A-CODE` displayed server-provided feedback.
- All product images loaded and no horizontal overflow occurred.

The final reload produced zero console errors, page errors, and failed requests. API health, catalogue, discount, checkout, and CORS requests all returned their expected successful responses.

## Automated Validation

```text
Backend: Ruff passed, strict mypy passed, 8 API tests passed, 97.92% coverage
Frontend: 3 behavior tests passed, ESLint passed, TypeScript/Vite build passed
Browser: desktop and mobile journeys passed with zero runtime errors
Human review: approved
```

## Outcome

Stage 3 passed and was approved. The application is ready for Stage 4 observability and release-correlation instrumentation.