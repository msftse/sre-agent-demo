# Stage 13: GitHub Connector Capability Validation

## Goal

Give Azure SRE Agent the minimum GitHub tool surface needed to inspect Northstar source, create an incident branch, commit a repair, and open a pull request automatically. Keep merge, review, and deployment actions outside the agent tool boundary so the user remains the human authorization point.

## Connection Design

Azure SRE Agent connects to GitHub's official remote MCP server at `https://api.githubcopilot.com/mcp/`. The idempotent `scripts/configure-sre-github-connector.sh` discovers the live server catalog before registering `northstar-github` through the SRE Agent data plane.

Stage 13 initially exposed five tools. Stage 16 added two narrowly scoped continuation tools, so seven are now visible to the agent:

| Tool | Purpose |
| --- | --- |
| `search_code` | Find relevant Northstar implementation and tests |
| `get_file_contents` | Read source from a branch or commit |
| `pull_request_read` | Verify signed callback-reported PR state |
| `create_branch` | Create the dedicated incident repair branch |
| `push_files` | Commit one or more repaired files to that branch |
| `create_pull_request` | Open the remediation PR without human preapproval |
| `add_issue_comment` | Publish the final evidence-backed RCA after deployment verification |

The connector does not expose `merge_pull_request`, pull-request review, Copilot-authored PR, general PR mutation, or branch-update tools. GitHub MCP did not advertise a workflow-dispatch tool in the discovered 47-tool catalog; the connector still uses an explicit allowlist so newly added tools cannot become available automatically.

## Authentication Boundary

The setup script reads the active GitHub CLI token at runtime and sends it directly to the SRE Agent data plane. It uses mode-0600 temporary files, removes them on exit, unsets token variables, and never prints the credential. The token is not stored in Git, Terraform state, or Azure Key Vault.

This demo credential belongs to `ij-23` and has broader GitHub scopes than the five selected MCP tools. The connector's exact tool selection is therefore the primary agent capability boundary. GitHub branch protection and the protected `demo` environment provide independent enforcement if a credential is used outside that tool surface. A production implementation should replace the interactive CLI credential with a dedicated, repository-scoped GitHub App or fine-grained service credential and a documented rotation process.

## Human Approval Boundaries

Routine branch protection remains active while implementation stages continue. Before the incident exercise, `scripts/configure-github-protection.sh incident-demo` will require:

- Successful `Validate source and chart` status.
- Resolution of review conversations.
- Admin enforcement with no force push or deletion.

The user must manually merge the validated PR. The `demo` environment independently accepts only `main` and requires `ij-23` approval. Repository workflow tokens default to read-only and cannot approve pull requests. The agent can therefore create the branch, commit, and PR automatically, but it cannot merge the PR or deploy the result with its selected tools.

## Live Validation

The official GitHub remote MCP server negotiated protocol `2025-06-18` and exposed 47 tools. Discovery confirmed that branch creation, multi-file commit, and PR creation are separate from merge and review operations.

The connector was created twice successfully to prove idempotency. A non-mutating `get_file_contents` call then read `README.md` from `refs/heads/main` and verified the expected Northstar title. No branch, commit, pull request, workflow, deployment, SRE investigation, or alert was created during Stage 13.

Run the repeatable live gate with:

```bash
./scripts/verify-github-connector.sh
```

The verifier checks the exact connector tool set without printing its authorization header, rejects forbidden tools, and verifies the live GitHub branch and environment controls.

## Outcome

Stage 13 is complete. Azure SRE Agent can read Northstar source and has the exact write primitives required for automatic branch, commit, and pull-request creation. Stage 14 subsequently packaged the checkout investigation and remediation procedure as a dedicated skill without granting merge or deployment capability.