# Stage 10: Deterministic Checkout Incident and Alert

## Goal

Prepare a repeatable application regression and Azure Monitor alert without starting the incident before Azure SRE Agent and Teams are connected. The scenario must break a business operation while pods, nodes, health probes, and unrelated checkout paths remain healthy.

## Regression

The source now contains one intentional missing-test regression in `checkout()`:

- A valid `FIELD20` quote is still returned by `/api/discounts/validate`.
- Checkout with `FIELD20` raises `discount_calculation_failed` with HTTP 500.
- Checkout without that code still succeeds.
- `/health/live` and `/health/ready` remain HTTP 200.
- Existing tests pass because they cover invalid FIELD20 thresholds and ordinary checkout, but not valid FIELD20 checkout.

This produces a realistic investigation story: infrastructure is healthy, the failure is isolated to a business path, logs and traces contain a stable error code, and the deployed Git SHA identifies the responsible release.

The fix PR created during the later SRE Agent exercise must add a valid FIELD20 checkout regression test before removing the erroneous failure path.

## Deterministic Traffic

The Helm traffic generator remains disabled by default. When enabled, one Restricted pod submits this request every five seconds through the frontend service:

```json
{
  "email": "load-generator@example.com",
  "discount_code": "FIELD20",
  "items": [
    {
      "product_id": "field-pack-28",
      "quantity": 2
    }
  ]
}
```

Two field packs create a `$296.00` subtotal, which always qualifies for FIELD20. The loop records failed curls and continues instead of crashing, so the failure signal remains steady. Cilium permits the traffic pod to reach only frontend plus DNS.

## Alert

Terraform manages:

| Resource | Name |
| --- | --- |
| Managed Prometheus rule group | Generated from the current AKS name; resource ID is `.checkout_rule_group_id` in the `observability` Terraform output |
| Alert | `NorthstarCheckoutFailureRatioHigh` |

The alert evaluates every minute and fires at severity 1 when both conditions remain true across two minutes:

- More than 50% of `POST /api/checkout` requests return HTTP 5xx.
- Checkout traffic exceeds `0.05` requests per second.

The minimum-rate guard prevents false alerts when no checkout traffic exists. Persistence is expressed with `min_over_time` subqueries because Checkov 3.3.9 cannot parse Terraform's otherwise valid Prometheus rule `for` attribute. The replacement expression was validated against live Managed Prometheus and restored zero Checkov parsing errors.

The alert auto-resolves after five healthy minutes. Stage 11 removed the temporary empty action group because Azure SRE Agent's native Azure Monitor incident platform scans the subscription directly and does not require action-group delivery.

## Deployment Control

The GitHub delivery workflow has a manual Boolean input:

```text
incident_traffic
```

Normal deployments leave it `false`. The eventual incident activation uses:

```text
deploy=true
incident_traffic=true
```

That one approved deployment builds and scans the exact regression commit, deploys immutable image digests, and starts deterministic traffic. Stage 10 does **not** dispatch this workflow.

## Verification

Historical Stage 10 validation snapshot (resource counts vary after recreation):

```text
Ruff: passed
mypy strict: passed
pytest: 12 passed, 96.07% coverage
Health endpoint: HTTP 200
Ordinary checkout: HTTP 200
Valid FIELD20 checkout: HTTP 500, discount_calculation_failed
Helm traffic-generator lint/render: passed
Managed Prometheus expression: valid and quiet on healthy baseline
Terraform: 31 resources, zero drift
Checkov: 24 passed, 0 failed, 13 reasoned skips, 0 parsing errors
Live AKS: backend 2/2 ready, traffic generator disabled
Fired Stage 10 alerts: 0
```

Terraform was applied through checksum-reviewed plans:

- Initial alert plan: two creates, zero updates, zero destroys.
- Parser-compatibility plan: one rule-group update, zero creates, zero destroys.

## Live Activation Sequence

Do not run this until Stage 11 has connected Azure SRE Agent and Stage 12 has connected Teams.

1. Enable incident GitHub protection:

   ```bash
   ./scripts/configure-github-protection.sh incident-demo
   ```

2. Dispatch `Deliver Demo to AKS` from `main` with `deploy=true` and `incident_traffic=true`.
3. Approve the protected `demo` environment deployment.
4. Verify pods remain Ready while FIELD20 checkouts return 500.
5. Observe the Managed Prometheus alert fire and begin the SRE Agent flow.

## Outcome

Stage 10 is complete and dormant. The incident code, deterministic traffic, and severity-1 alert are ready, but the healthy Stage 9 image remains deployed and no checkout alert is firing. Stage 11 can now create and connect Azure SRE Agent before the regression is activated.
