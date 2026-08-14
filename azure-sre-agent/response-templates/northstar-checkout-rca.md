# Northstar Checkout RCA Template

## Rendering Rules

- Publish only the rendered content beginning with `# Root Cause Analysis`.
- Preserve every heading and keep the heading order unchanged.
- Replace every `{{placeholder}}`; use `Not observed` or `Not applicable` when evidence does not support a value.
- Use UTC timestamps in ISO 8601 format.
- State only evidence-backed facts. Do not include credentials, request bodies, customer data, or unverified assumptions.
- Use the same rendered RCA for the GitHub pull-request comment and the final Microsoft Teams update.
- Set status to `Resolved` only after the alert, release, workload, checkout, and telemetry checks all pass. Otherwise use `Deferred` and identify the blocker.

---

# Root Cause Analysis: {{incident_title}}

## Incident Summary

- Status: {{Resolved|Deferred}}
- Severity: {{severity}}
- Azure incident ID: {{incident_id}}
- SRE thread ID: {{sre_thread_id}}
- Teams incident ID: {{teams_incident_id}}
- Affected service: {{affected_service}}
- Environment: {{environment}}
- Started (UTC): {{started_at}}
- Resolved (UTC): {{resolved_at_or_not_resolved}}
- Remediation PR: {{pull_request_url}}
- Remediation merge SHA: {{merge_sha_or_not_merged}}
- Deployed release: {{deployed_sha_and_image_digest}}

## Executive Summary

{{Summarize the impact, direct cause, remediation, and current outcome in two or three sentences.}}

## Impact

- User impact: {{user_impact}}
- Scope: {{affected_scope}}
- Duration: {{impact_duration}}
- Healthy paths: {{unaffected_routes_or_components}}

## Detection

- Alert: {{alert_name_and_condition}}
- Detection time (UTC): {{detected_at}}
- Trigger evidence: {{request_rate_failure_ratio_and_window}}

## Timeline (UTC)

- {{timestamp}} - Alert fired: {{evidence}}
- {{timestamp}} - Investigation started: {{evidence}}
- {{timestamp}} - Root cause confirmed: {{evidence}}
- {{timestamp}} - Remediation PR opened: {{evidence}}
- {{timestamp}} - Human merge completed: {{evidence}}
- {{timestamp}} - Recovery deployed: {{evidence}}
- {{timestamp}} - Recovery verified or deferred: {{evidence}}

## Evidence

- Alert and metrics: {{alert_metric_evidence}}
- AKS health: {{cluster_deployment_and_pod_evidence}}
- Logs: {{error_code_operation_trace_pod_sha_and_digest}}
- Traces: {{request_span_and_discount_code_evidence}}
- Source: {{faulting_code_path_and_test_gap}}
- Recovery: {{recovery_operation_http_result_totals_sha_digest_and_alert_state}}

## Root Cause

- Direct cause: {{direct_technical_cause}}
- Contributing factors: {{contributing_factors_or_none}}
- Rejected hypotheses: {{rejected_hypotheses_and_evidence}}

## Remediation

- Code change: {{minimal_code_change}}
- Regression coverage: {{test_case_and_expected_totals}}
- Human decision: {{review_and_merge_actor_boundary}}
- Deployment: {{workflow_run_and_release_identity}}

## Recovery Validation

- Workload health: {{replica_and_probe_result}}
- FIELD20 checkout: {{operation_id_http_result_and_totals}}
- Telemetry correlation: {{trace_id_span_and_checkout_discount_code}}
- Failure signal: {{post_deployment_failure_ratio_or_request_outcomes}}
- Alert state: {{resolved_state_and_timestamp_or_deferred_blocker}}

## Follow-up Actions

- {{action}} - Owner: {{owner}} - Status: {{status}} - Due: {{due_date_or_not_applicable}}

## Rollback

{{Describe the immutable release or commit to restore and the condition that would trigger rollback.}}