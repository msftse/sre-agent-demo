## Change

Describe the problem, proposed change, and expected operational effect.

## Evidence

- [ ] Backend checks pass: Ruff, mypy, and pytest
- [ ] Frontend tests, lint, build, and shipped-dependency audit pass
- [ ] Helm chart lint and render checks pass
- [ ] No Terraform state, saved plans, credentials, or generated secrets are included
- [ ] Deployment-impacting images are identified by immutable Git SHA and registry digest

## Human Decision

- [ ] I reviewed the implementation and evidence
- [ ] I approve this change for merge into `main`
- [ ] I understand that deployment remains a separate, protected `demo` environment action
