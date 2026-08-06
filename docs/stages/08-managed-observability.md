# Stage 8: Managed Azure Observability

## Goal

Connect the healthy AKS baseline to Azure Monitor managed service for Prometheus, Log Analytics, workspace-based Application Insights, and Azure Managed Grafana. Preserve the existing bounded signal contract, immutable release identity, Restricted workload posture, and passwordless authentication.

## Deployed Resources

| Component | Name | Purpose |
| --- | --- | --- |
| Azure Monitor workspace | `amw-sre-agent-demo-demo-ij2608` | Managed Prometheus storage and query endpoint |
| Log Analytics workspace | `log-sre-agent-demo-demo-ij2608` | Container Insights and AKS control-plane logs |
| Application Insights | `appi-sre-agent-demo-demo-ij2608` | OpenTelemetry request, dependency, and exception telemetry |
| Azure Managed Grafana | `amg-sreage-demo-ij2608` | Managed Prometheus visualization |
| Prometheus DCR | `MSProm-aks-sre-agent-demo-demo-ij2608` | Routes `Microsoft-PrometheusMetrics` to the monitor workspace |
| Container Insights DCR | `MSCI-aks-sre-agent-demo-demo-ij2608-swedencentral` | Routes cost-scoped Northstar logs and inventory |
| Telemetry identity | `id-telemetry-aks-sre-agent-demo-demo-ij2608` | Passwordless Application Insights ingestion |

Managed Grafana uses Standard SKU and major version 12, the supported intersection of the live Azure API and locked AzureRM 4.81 provider.

## Collection Design

AKS now enables its native `monitor_metrics` and MSI-authenticated `oms_agent` profiles. Terraform also owns the required DCR/DCRA resources:

- Managed Prometheus collects `Microsoft-PrometheusMetrics`.
- Container Insights collects `ContainerLogV2`, `KubeEvents`, and `KubePodInventory`.
- Container Insights uses a five-minute interval and includes only namespace `northstar` for cost control.
- AKS diagnostic settings send `kube-apiserver`, `kube-audit-admin`, and `guard` to resource-specific Log Analytics tables.
- Grafana's system identity receives `Monitoring Data Reader` only on the Azure Monitor workspace.

The live subscription had already enabled Defender for Containers on AKS. Its profile points to the subscription security workspace and is outside this environment's Terraform ownership. The AKS module ignores the `microsoft_defender` block so monitoring updates cannot disable that security control.

## Application Insights

The backend retains its custom OpenTelemetry server and checkout spans. When `APPLICATIONINSIGHTS_CONNECTION_STRING` is present, it adds:

- `ApplicationInsightsSampler` with the configured ratio.
- `BatchSpanProcessor`.
- `AzureMonitorTraceExporter`.
- `DefaultAzureCredential` backed by AKS workload identity.

The `northstar-sre-demo-workload` service account federates to the telemetry user-assigned identity. That identity receives `Monitoring Metrics Publisher` only on the Application Insights component. Local authentication remains disabled on Application Insights, so the connection string alone cannot ingest telemetry.

The Azure exporter requires the SDK tracer provider to be globally registered to derive resource metadata. Local and injected test exporters continue to use isolated providers; the Azure-enabled production path registers its provider globally.

## Kubernetes Integration

Helm release `northstar` revision 5 runs the final Stage 8 image set:

| Image | Git SHA | Digest |
| --- | --- | --- |
| Backend | `0e23af6890c3` | `sha256:2ee86a1681b5e94bdbf3287e325ddb7e0c7aa565f618eeb2da52f34bbb9b6de1` |
| Frontend | `0e23af6890c3` | `sha256:54df91373947a521a6e7f96f30073933e9d8534c86733f2b35222b006f61adc9` |

Both images were built on the local Docker daemon and published with `docker push`. The Azure Monitor `ServiceMonitor` selects the backend service's named `metrics` port and scrapes `/metrics` every 30 seconds.

The backend NetworkPolicy permits DNS plus TCP 443 egress. HTTPS is required for Microsoft Entra workload identity token exchange and Application Insights ingestion. Backend ingress remains restricted to frontend, monitoring, and the labeled Helm test pod.

## Apply Recovery

The approved initial plan contained 13 creates, one monitoring-only AKS update, and zero destroys. It applied AKS and 11 resources before Azure rejected Managed Grafana major version 11; the live Standard API accepts only 12 or 13. AzureRM 4.81 accepts 11 or 12, making 12 the compatible choice.

A second checksum-reviewed recovery plan contained only Managed Grafana 12 and its `Monitoring Data Reader` role. It completed with two creates and zero destroys. Final Terraform state contains 29 resources and reports no drift.

## Verification

Infrastructure and agents:

```text
AKS provisioning: Succeeded
Managed Prometheus profile: enabled
Container Insights add-on: enabled with Microsoft Entra authentication
Defender security monitoring: enabled and preserved
ama-metrics-node: 2/2 ready
ama-logs: 2/2 ready
ama-metrics: 2/2 ready
ama-metrics-ksm: 1/1 ready
ama-logs-rs: 1/1 ready
ServiceMonitor CRD: installed
Terraform resources: 29
Terraform drift: none
Live tag audit: 21 resources, 1 explicit non-taggable smart detector exclusion
```

Application and signal proof:

```text
Helm release: northstar revision 5, deployed
Helm smoke test: Succeeded
Backend and frontend replicas: 4/4 ready
Application Insights: 786 requests, 9 dependencies, 1 exception observed
Managed Prometheus: 2 northstar_build_info series for Git SHA 0e23af6890c3
ContainerLogV2: correlated stage8 operation IDs, trace IDs, and 200/422 outcomes
```

Example PromQL:

```promql
northstar_build_info{git_sha="0e23af6890c3"}
```

Example KQL:

```kusto
ContainerLogV2
| where PodNamespace == "northstar"
| extend Payload = parse_json(LogMessage)
| where isnotempty(Payload.operation_id)
| project TimeGenerated,
          OperationId=tostring(Payload.operation_id),
          TraceId=tostring(Payload.trace_id),
          StatusCode=toint(Payload.status_code)
| order by TimeGenerated desc
```

```kusto
requests
| where cloud_RoleName == "Northstar Supply API"
| summarize Requests=count(), Latest=max(timestamp), ResultCodes=make_set(resultCode)
```

Managed Grafana endpoint:

```text
https://amg-sreage-demo-ij2608-gbhdd3bcdeedg2fx.cse.grafana.azure.com
```

Application Insights automatically creates a `Failure Anomalies` smart detector child. AzureRM and the live ARM resource expose no writable tags for `Microsoft.AlertsManagement/smartDetectorAlertRules`, so the live audit reports and excludes only that exact non-taggable type.

## Outcome

Stage 8 is complete. Metrics, logs, traces, release identity, operation IDs, and trace IDs are queryable across the managed Azure observability stack. Stage 9 can now automate the already-proven local build, ACR push, digest-pinned Helm upgrade, and verification flow through protected GitHub Actions.
