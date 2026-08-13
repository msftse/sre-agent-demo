# Stage 9: Protected GitHub Actions Delivery

## Goal

Turn the validated local build and Helm procedure into a human-governed GitHub Actions delivery path. A proposed SRE Agent fix must pass automated validation before the user manually merges it. Deployment then uses short-lived Azure OIDC credentials, locally built images, critical-CVE gates, immutable ACR digests, and live AKS verification.

## Workflow

Workflow: `.github/workflows/deliver-demo.yml`

Pull requests to `main` run only the `Validate source and chart` job:

1. Backend dependency sync, Ruff, strict mypy, and pytest.
2. Frontend install, tests, lint, production build, and shipped-dependency audit.
3. Helm lint and default/Azure Monitor render checks.

Deployment remains separately authorized:

1. Merge a validated same-repository `sre/field20-checkout-*` remediation PR to start recovery automatically with incident traffic disabled, or manually dispatch `Deliver Demo to AKS` on `main` for incident activation or operator recovery.
2. Approve the protected `demo` environment as `ij-23`; neither trigger can deploy before this approval.
3. Exchange GitHub's environment-bound OIDC token for a short-lived Azure token.
4. Verify the Azure subscription and tenant.
5. Authenticate the local runner Docker daemon to ACR.
6. Build AMD64 images locally and publish them with `docker push`.
7. Block deployment on fixed critical vulnerabilities and generate SPDX SBOMs.
8. Connect to Entra-integrated AKS through pinned kubectl, kubelogin, and Helm versions.
9. Atomically deploy immutable image digests.
10. Verify replicas, full Git SHA, exact digests, telemetry identity, ServiceMonitor, and Helm smoke tests.

The deployment job has only `contents: read` and `id-token: write`. All third-party actions are pinned by commit SHA. Concurrent demo deployments are serialized and never cancelled in progress.

## Human Approval Boundaries

The repository is public so GitHub Free can enforce protection rules.

The validated `incident-demo` branch protection profile requires:

- Successful `Validate source and chart` status.
- Resolution of review conversations.
- Linear history.
- Enforcement for administrators.
- No force pushes or branch deletion.

The `demo` environment always:

- Accepts deployments only from `main`.
- Requires approval from `ij-23`.
- Allows self-review at deployment time because `ij-23` is currently the sole reviewer.

The user-performed merge is the source authorization boundary and starts the recovery workflow automatically. The environment approval is a separate operational authorization, and the agent can perform neither action.

Routine implementation stages use the `routine` profile so normal demo-building changes can be committed directly without creating artificial PRs. Before the SRE Agent incident exercise, switch back to the enforced profile:

```bash
./scripts/configure-github-protection.sh incident-demo
```

After the exercise, return to routine development with:

```bash
./scripts/configure-github-protection.sh routine
```

PRs are reserved for code fixes authored after an actual SRE Agent investigation. The public-repository bootstrap PR proved the required review and status-check behavior before routine mode was restored.

## Immutable OIDC Trust

This repository was created after GitHub's July 15, 2026 immutable-subject cutover. Azure trusts the exact environment subject:

```text
repo:msftse@259423729/sre-agent-demo@1323141369:environment:demo
```

Terraform constructs the immutable subject from explicit owner and repository IDs and manages the federated credential in place. The GitHub deployment identity retains only `AcrPush`, AKS Cluster User, and AKS RBAC Cluster Admin roles at the relevant resources. No Azure client secret is stored in GitHub.

Repository Actions configuration contains eight non-secret variables and one masked Application Insights connection-string secret. The connection string cannot ingest telemetry by itself because Application Insights local authentication is disabled; the pod still requires its workload identity.

## Security Gate Proof

The original Stage 9 delivery run, [31104579216](https://github.com/msftse/sre-agent-demo/actions/runs/31104579216), is historical validation evidence that the gate failed closed:

- OIDC, Azure context, ACR login, and immutable image pushes succeeded.
- Trivy found `CVE-2026-31789` in frontend `libcrypto3` and `libssl3` version `3.5.5-r0`.
- The fixed Alpine version was `3.5.6-r0` or later.
- Deployment steps were skipped.

The frontend runtime now upgrades only `libcrypto3` and `libssl3` as root, then restores UID/GID `101` before application content is copied. Local Trivy `v0.73.0` reported zero critical findings with patched version `3.5.7-r0`.

The original Stage 9 replacement run, [31112420552](https://github.com/msftse/sre-agent-demo/actions/runs/31112420552), is historical validation evidence that the protected path completed successfully:

```text
Validation: passed
GitHub OIDC login: passed
Azure/ACR context: passed
Local Docker builds and pushes: passed
Critical-CVE scans: passed
SPDX SBOM generation: passed
Digest-pinned Helm deployment: passed
Live AKS verification and Helm test: passed
```

## Historical Stage 9 Release

The original Stage 9 snapshot used Helm revision 6 and this commit:

```text
61f739ca6d55bc734ad67e3171da3b83994c3912
```

| Image | Digest |
| --- | --- |
| Backend | `sha256:1cc82d9255d1ff511cf0332668b25c0ec5f2851393f764f67b15448be1d8d9f8` |
| Frontend | `sha256:a39f0e1c5e2462e82f71c1c1411473e3aaee7dca409ccdc528c2ebd4af645f49` |

These values are audit evidence, not inputs or expectations for a recreated environment. The reusable `scripts/verify-deployment.sh` validates the same contract locally and in GitHub Actions using the current release values.

## Verification

Validated outcomes:

```text
Workflow syntax: actionlint passed
Shell scripts: ShellCheck and bash syntax passed
Terraform: 29 resources, zero drift
Checkov: 24 passed, 0 failed
Azure tags: 21 resources audited, one explicit non-taggable exclusion
GitHub environment: main-only plus required reviewer
GitHub main branch: validation and user-performed merge required
AKS deployments: 4/4 replicas ready
Helm smoke test: succeeded
```

## Outcome

Stage 9 is complete. The demo has a validated, repeatable human merge profile and a separately approved, secretless, scan-gated, immutable deployment path to AKS. Routine mode is currently active; the incident-demo profile must be enabled before the SRE Agent creates its remediation PR. Stage 10 can introduce the deterministic checkout regression and Azure Monitor alert without creating a setup PR.
