# Implementation Stages

This tracker is the learning path for the Azure SRE Agent closed-loop demo. A stage advances only after its focused checks pass and the user reviews the result.

| Stage | Progress | Outcome | Status |
| --- | ---: | --- | --- |
| 1 | 0-5% | Preflight and repository bootstrap | Complete |
| 2 | 5-16% | Healthy FastAPI backend and React storefront | Complete |
| 3 | 16-22% | Backend and frontend running locally for user review | Complete |
| 4 | 22-30% | Local metrics, logs, traces, and release correlation | Complete |
| 5 | 30-36% | Hardened containers and Helm deployment | Complete |
| 6 | 36-43% | Modular Terraform foundation under `iac/` | Complete |
| 7 | 43-53% | Core Azure and AKS platform | Complete |
| 8 | 53-63% | Managed Prometheus, Log Analytics, Application Insights, and Grafana | Complete |
| 9 | 63-71% | Protected GitHub Actions delivery | Complete |
| 10 | 71-77% | Deterministic checkout incident and alert | Complete |
| 11 | 77-83% | Azure SRE Agent and Azure Monitor incident platform | Not started |
| 12 | 83-87% | Teams connector and threaded incident notifications | Not started |
| 13 | 87-90% | GitHub connector capability validation | Not started |
| 14 | 90-94% | Incident responder and mandatory Teams timeline | Not started |
| 15 | 94-97% | GitHub-to-agent-to-Teams continuation loop | Not started |
| 16 | 97-99% | Full approval and rejection dress rehearsal | Not started |
| 17 | 99-100% | Final learning materials and Terraform teardown | Not started |

## Stage Protocol

Before each stage:

1. Explain the goal, components, files, commands, cost or operational impact, and success criteria.
2. Confirm any interactive or potentially destructive checkpoint.

At the end of each stage:

1. Run the narrowest executable validation for the changed behavior.
2. Summarize what was built and what the checks proved.
3. Synchronize the project documentation.
4. Review, commit, and push the scoped stage changes.
