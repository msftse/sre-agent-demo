# Stage 18: Azure Architecture Design Proposal

## Ownership

This stage was completed by the **user** with **Codex** using the `azure-architecture-proposal` skill. The regular implementation agent did not generate the proposal.

## Goal

Create a polished, customer-facing architecture design for the Azure SRE Agent closed-loop demo by invoking the `azure-architecture-proposal` skill. The proposal must explain the deployed end-to-end incident flow and its human approval boundaries to an engineering audience with limited Azure experience.

## Proposal Profile

| Input | Stage decision |
| --- | --- |
| Proposal type | General/greenfield Azure proposal |
| Subject | Northstar Azure SRE Agent closed-loop incident response demo |
| Audience | Platform, SRE, application, security, and engineering leadership |
| Source context | Repository documentation, Terraform, application code, live Azure resources, verified Stage 1-16 evidence, and the Stage 17 rehearsal design |
| Delivery owner | User with Codex |
| Deliverable | One self-contained HTML file with all selected images embedded |
| Planned path | `docs/architecture/sre-agent-demo-architecture.html` |
| Azure changes | None; this is a design/documentation stage |

This is not a cloud migration mapping. The document must use the skill's greenfield/general structure and justify each Azure service against the demo's actual requirements rather than adding generic platform recommendations.

## Required Content

The proposal should include only sections relevant to this demo:

1. Executive abstract and how to read the document.
2. Azure 101 primer for the intended audience.
3. Subscription and resource-group topology.
4. Human identity, workload identity, GitHub OIDC, and secret handling.
5. AKS, ACR, networking, and protected delivery architecture.
6. Managed Prometheus, Log Analytics, Application Insights, and Grafana signal flow.
7. Azure Monitor alert discovery and Azure SRE Agent investigation flow.
8. Teams bot, Functions Flex bridge, Key Vault, storage, and automated MCP connector.
9. GitHub connector, checkout skill, response plan, pull-request boundary, automatic main-only deployment, verification, and RCA continuation.
10. Security/trust-boundary table that distinguishes autonomous actions from human approvals.
11. Phased build and demonstration sequence aligned to the implementation stages.
12. Open questions and glossary.

## Architecture Messages

Generate only diagrams that materially teach the design. At minimum, the proposal needs:

- **Closed-loop operating model:** alert → investigation → Teams timeline → source fix PR → human merge → automatic main-only deployment → verification/RCA.
- **Identity and authorization boundaries:** Azure UAMIs/RBAC, Bot Connector identity, MCP custom-header authentication, GitHub permissions, branch protection, and environment branch policy.
- **Azure deployment topology:** AKS application and observability resources, Azure SRE Agent, Teams bridge resources, and external GitHub/Teams boundaries.

Follow the skill's architecture interpreter → layout designer → image renderer/validator workflow. Do not render diagrams directly from prose. The final selected diagrams must be presentation-resolution PNGs embedded into the HTML as data URIs.

## Evidence and Accuracy Rules

- Verify every Azure service, API version, identity role, region, and behavior against current Microsoft documentation or live resources during this stage.
- Base the design on the implemented Stage 1-17 system. Keep any production hardening recommendations or Stage 19 teardown actions visually distinct from deployed state.
- Do not include secret values, tenant-internal credentials, Terraform state, or sensitive connector headers.
- Record material unknowns as open questions rather than silently choosing production scale, DR, compliance, or residency requirements.
- Confirm every external documentation link resolves before including it.
- Run the skill's editorial pass and remove repeated recommendations.

## Validation

Stage 18 completion criteria:

1. The HTML opens directly with no build step or external local assets.
2. All images are embedded and render correctly on desktop and mobile widths.
3. Architecture diagrams are inspected as rendered pixels and meet the skill quality rubric.
4. Deployed components and optional production recommendations are unambiguous.
5. Every Azure claim and external link is verified.
6. The security and approval boundaries match the implemented repository controls.
7. Open questions and glossary are complete.
8. Documentation is synchronized, reviewed, committed, and pushed.

## Outcome

Stage 18 is complete. The user-owned, self-contained proposal is available at [docs/architecture/sre-agent-demo-architecture.html](../architecture/sre-agent-demo-architecture.html) with three embedded architecture diagrams, security and approval boundaries, open questions, a glossary, and verified Microsoft references. Stage 17 subsequently proved the documented closed loop against the live environment. Stage 19 can finalize learning materials and tear down the demo after the requested repeat E2E run.