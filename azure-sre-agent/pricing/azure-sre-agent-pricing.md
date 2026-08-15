# Azure SRE Agent Pricing and Cost Management

Pricing snapshot: **2026-08-14**

This document explains the public Azure SRE Agent billing model, shows how to estimate monthly cost, and records the pricing-relevant configuration of this demo environment. Prices are estimates, not quotes. Your Azure agreement, offer, region, currency, taxes, and future service updates can change the amount billed.

## Executive Summary

Azure SRE Agent is billed in **Azure Agent Units (AAUs)** at a public list price of **$0.10 USD per AAU**. The monthly cost has two components:

1. **Always-on flow:** fixed at 4 AAUs for every hour each agent exists.
2. **Active flow:** variable AAUs calculated from model input, output, cache-read, and cache-write tokens while the agent is processing work.

At 730 hours in a typical planning month, one existing agent incurs approximately:

$$
4\ \text{AAU/hour} \times 730\ \text{hours} \times \$0.10/\text{AAU} = \$292
$$

This baseline continues while the agent is running **or stopped**. Deleting the agent is the only documented way to stop the always-on charge.

There is **no free tier**. Charges begin when the agent is created.

## Billing Components

### Always-On Flow

| Item | Public rate |
| --- | ---: |
| Always-on consumption | 4 AAUs per agent-hour |
| Public AAU price | $0.10 per AAU |
| Effective hourly cost | $0.40 per agent-hour |
| 730-hour planning month | $292.00 per agent |
| 744-hour, 31-day month | $297.60 per agent |

Always-on flow represents the cost of keeping the agent provisioned and available. It is not a measure of active investigation time.

Billing lifecycle:

| Agent state | Active-flow charges | Always-on charges |
| --- | --- | --- |
| Running and idle | None until work starts | Continue |
| Running and processing | Continue based on tokens | Continue |
| Waiting for user approval or input | No active processing charge | Continue |
| Stopped | Stop | Continue |
| Deleted | Stop | Stop |

### Active Flow

Active flow is consumed whenever the agent performs work, including:

- Interactive portal, Playground, or Teams conversations.
- Azure Monitor incident investigations and response plans.
- Scheduled tasks and HTTP or platform triggers.
- Background analysis, report generation, and remediation work.

Waiting for a user response or approval does not count as active processing. Active-flow counters reset at the start of each calendar month.

## Token-to-AAU Conversion

For a task with token counts $T_i$, $T_o$, $T_{cr}$, and $T_{cw}$, active AAUs are:

$$
\text{Active AAUs} =
\frac{T_i}{1{,}000{,}000}R_i +
\frac{T_o}{1{,}000{,}000}R_o +
\frac{T_{cr}}{1{,}000{,}000}R_{cr} +
\frac{T_{cw}}{1{,}000{,}000}R_{cw}
$$

where each $R$ is the AAU rate for the configured model and token type.

Public rates per 1 million tokens:

| Model | Input | Output | Cache read | Cache write |
| --- | ---: | ---: | ---: | ---: |
| Claude Opus 4.6 | 100 AAUs | 500 AAUs | 10 AAUs | 125 AAUs |
| GPT 5.3 Codex | 35 AAUs | 280 AAUs | 3.5 AAUs | 0 AAUs |
| GPT 5.2 | 35 AAUs | 280 AAUs | 3.5 AAUs | 0 AAUs |

Azure can add models or change AAU conversion rates. Always verify the current model table before approving a budget.

## Published Task Examples

Microsoft publishes the following approximate task profiles:

| Scenario | Input | Output | Cache read | Cache write | Claude Opus 4.6 | GPT 5.3 Codex |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Quick question | 20K | 2K | 15K | 5K | 3.8 AAUs / $0.38 | 1.3 AAUs / $0.13 |
| Incident investigation | 200K | 15K | 150K | 50K | 35.3 AAUs / $3.53 | 11.7 AAUs / $1.17 |
| Full remediation | 500K | 40K | 400K | 100K | 86.5 AAUs / $8.65 | 30.1 AAUs / $3.01 |

These examples are directional. Actual cost depends on investigation length, tool-result size, model behavior, retries, context, cache usage, and the number of reasoning steps.

## Monthly Cost Formula

For $N$ agents that exist for $H$ hours and consume $A$ active-flow AAUs:

$$
\text{Monthly cost} = \$0.10 \times (4NH + A)
$$

Example estimates using a 730-hour month:

| Workload | Always-on | Active flow | Estimated total |
| --- | ---: | ---: | ---: |
| One idle agent | $292.00 | $0.00 | $292.00 |
| One agent + 10 GPT incident investigations | $292.00 | $11.70 | $303.70 |
| One agent + 10 GPT full remediations | $292.00 | $30.10 | $322.10 |
| One agent + 10 Claude full remediations | $292.00 | $86.50 | $378.50 |
| Two idle agents | $584.00 | $0.00 | $584.00 |

Consolidating multiple monitored workloads under one appropriately scoped agent can reduce fixed cost because the always-on charge is per agent.

## Allocation Limits and Spending Controls

In the SRE Agent portal, go to **Settings** > **Agent consumption** > **Change AAU allocation**.

| Control | Behavior |
| --- | --- |
| Minimum active-flow allocation | 500 AAUs per month |
| Maximum active-flow allocation | 1,000,000 AAUs per month |
| Increase allocation | Takes effect immediately |
| Decrease allocation | Takes effect next month |
| Reach allocation limit | Chat and actions stop until reset or allocation increase |
| Monthly reset | Beginning of each calendar month |
| Effect on always-on flow | None; fixed billing continues |

The allocation is an active-flow operational limit, not a complete Azure budget. Create Azure Cost Management budgets and alerts separately for financial governance.

## This Demo Environment

An example live ARM output for this demo pattern is:

| Property | Value |
| --- | --- |
| Agent | Example: `sre-sre-agent-demo-demo-<suffix>` |
| Region | Sweden Central |
| Upgrade channel | Stable |
| `monthlyAgentUnitLimit` | 10,000 AAUs |

At the public rate, consuming the entire 10,000-AAU active-flow allocation would cost approximately **$1,000**, in addition to the fixed always-on cost. Using a 730-hour month, the approximate upper planning amount is:

$$
\$1{,}000 + \$292 = \$1{,}292
$$

This is not a forecast of expected use. It is the public-price result if the full configured active-flow allocation is consumed.

## Monitoring Consumption

Go to **Settings** > **Agent consumption** in [sre.azure.com](https://sre.azure.com) to review:

- Monthly AAU limit.
- Total active-flow consumption by Chats, Incidents, Scheduled tasks, and Triggers.
- Daily active-flow consumption.
- Per-thread AAU consumption and status.
- Up to six months of usage history.
- CSV export of the filtered thread table.

Use Azure Cost Management for billing views across agents, subscriptions, and related Azure resources.

## Related Azure Costs

The Azure SRE Agent FAQ states that SRE Agent pricing includes agent compute and orchestration, conversation and knowledge-base storage, AI model usage, and Azure-service integration. However, the workloads and telemetry services that the agent reads can have their own charges.

Review these separately:

- Azure Monitor Logs and Log Analytics ingestion, retention, archive, search, and query features.
- Application Insights telemetry ingestion and retention through its workspace.
- Managed Prometheus and Managed Grafana used by the monitored platform.
- AKS, container registry, storage, networking, Functions, Key Vault, Bot Service, and other demo infrastructure.
- External products or licenses reached through GitHub, Teams, MCP, or other connectors.

Do not treat the AAU estimate as the total cost of this repository's Azure environment.

## Cost Optimization Guidance

1. **Use focused response plans.** Filter by severity, service, and alert title so unrelated incidents do not consume active AAUs.
2. **Disable recurrence merging only when operationally necessary.** Distinct investigations improve determinism but can increase active-flow usage when alerts flap.
3. **Keep skills and templates concise and grounded.** Clear procedures reduce exploratory reasoning, unnecessary tool calls, and repeated context.
4. **Prefer preconfigured observability connectors for repeated targets.** Microsoft notes that skipping repeated discovery can reduce latency and token consumption.
5. **Test prompts before automating.** A misconfigured schedule or trigger can repeatedly consume AAUs.
6. **Batch periodic work.** Prefer daily or weekly scheduled checks over continuous polling where the use case permits.
7. **Review per-thread outliers.** Export consumption and investigate expensive incident, chat, or trigger threads.
8. **Select the model deliberately.** Compare total task AAUs, not only per-token rates; a higher-rate model can sometimes finish complex work in fewer steps.
9. **Stop idle agents only to eliminate active flow.** Stopping does not remove the fixed baseline.
10. **Delete unused agents.** Deletion is the documented action that ends both billing components.

## Pricing Data Caveats

- Public prices are estimates and can differ by agreement, offer, currency, and region.
- The Azure Retail Prices API returned no standalone `Azure SRE Agent` consumption rows when this document was prepared. The Azure SRE Agent pricing page and pricing calculator are therefore the public rate sources used here.
- Model AAU conversion rates can change as Azure adds models or providers.
- Recheck all rates and limits before procurement, production rollout, or budget approval.

## Official References

- [Azure SRE Agent pricing page](https://azure.microsoft.com/pricing/details/sre-agent/)
- [Pricing and billing for Azure SRE Agent](https://learn.microsoft.com/azure/sre-agent/pricing-billing)
- [Monitor agent usage](https://learn.microsoft.com/azure/sre-agent/monitor-agent-usage)
- [Azure SRE Agent overview](https://learn.microsoft.com/azure/sre-agent/overview)
- [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator/?service=sre-agent)
- [Azure Cost Management](https://portal.azure.com/#view/Microsoft_Azure_CostManagement/Menu/~/overview)
- [Azure Monitor Logs cost calculations](https://learn.microsoft.com/azure/azure-monitor/logs/cost-logs)