# AGENTS.md - AI Coding Agent Instructions

This document instructs AI coding agents on how to work with this repository.

## Project Overview

This is a **Helm chart monorepo** for deploying and managing OpenShift clusters on AWS using ROSA HCP (Red Hat OpenShift Service on AWS - Hosted Control Plane) with dedicated VPC configurations. It follows a **GitOps-first** architecture driven by ArgoCD.

**This repo is the GitOps arm of [validated-pattern-terraform-rosa](https://github.com/rh-mobb/validated-pattern-terraform-rosa)**. That Terraform repo provisions ROSA HCP clusters; after cluster creation, its bootstrap step installs the `cluster-bootstrap` Helm chart, which brings up OpenShift GitOps and deploys these charts.

The charts are published to a Helm repository at `https://rh-mobb.github.io/validated-pattern-helm-charts/`.

### Architecture

```
Terraform -> cluster-bootstrap -> OpenShift GitOps -> ArgoCD ApplicationSets
                                                           |
                        +----------------------------------+----------------------------------+
                        |                                                                     |
              app-of-apps-infrastructure                                        app-of-apps-application
                        |                                                                     |
              Infrastructure Charts                                           app-of-apps-namespaces
         (EFS, logging, compliance, etc.)                                             |
                                                                                 namespaces
                                                                          (team resources, RBAC)
```

Configuration values live in a **separate** `cluster-config` repository, not in this repo.

## Repository Structure

```
.github/
  cr-config.yaml                 # Chart Releaser configuration
  workflows/
    pull-request.yml             # Lint changed charts on PRs
    update-index.yml             # Release charts on push to main
charts/
  cluster-bootstrap/             # GitOps bootstrap (Terraform-deployed)
  cluster-bootstrap-acm-spoke/   # ACM spoke cluster variant
  cluster-bootstrap-acm-hub-registration/
  app-of-apps-infrastructure/    # Orchestrates infrastructure charts via ArgoCD
  app-of-apps-application/       # Orchestrates team namespace charts via ArgoCD
  app-of-apps-namespaces/        # Deploys individual team namespaces
  app-of-apps-*-acm/             # ACM variants of app-of-apps charts
  helper-operator/               # Reusable sub-chart for installing OLM operators
  helper-status-checker/         # Reusable sub-chart for operator readiness checks
  helper-installplan-approver/   # InstallPlan auto-approval (Helm hooks, not ArgoCD)
  application-gitops/            # Team-specific ArgoCD instance configuration
  namespaces/                    # Namespace creation with RBAC, quotas, network policies
  cluster-logging/               # CloudWatch + optional Loki logging
  cluster-efs/                   # AWS EFS CSI storage
  compliance-operator/           # OpenShift compliance scanning
  deploy-operator/               # Generic chart for lightweight operators (web-terminal, openshift-pipelines, etc.)
  ...                            # 50+ charts total
  update-helper-charts.sh        # Bulk-update helper-status-checker across charts
README.md
.gitignore
```

All Helm charts live under `charts/`. There is no Makefile; Helm CLI and GitHub Actions are the primary interfaces.

## Chart Anatomy

Every chart follows this layout:

```
charts/<chart-name>/
  Chart.yaml       # Metadata, version, dependencies
  values.yaml      # Default values (documented with comments)
  README.md        # Per-chart documentation (required)
  templates/
    _helpers.tpl   # Template helpers (optional; used by namespaces, milvus, etc.)
    *.yaml         # Kubernetes resource templates
```

### Chart.yaml Conventions

- Use `apiVersion: v2` (Helm 3).
- Include `home` and `maintainers` fields (required by chart-tester). Example: see `charts/cluster-logging/Chart.yaml`.
- End `Chart.yaml` with a trailing newline.
- The `version` field uses strict semver (`MAJOR.MINOR.PATCH`). No `v` prefix.
- Dependencies reference the Helm repository URL: `https://rh-mobb.github.io/validated-pattern-helm-charts/`.
- Use tilde ranges (`~1.1.0`) for helper chart dependency versions to allow patch updates.
- Use `condition:` to make optional dependencies toggleable (e.g., `condition: helper-status-checker.enabled`).

### values.yaml Conventions

- Use empty-string defaults for environment-specific values: `roleArn: ""`, `clustername: ""`, `region: ""`.
- Prefix sub-chart values with the dependency name: `helper-operator:`, `helper-status-checker:`.
- Document values with inline YAML comments. Use `@default` annotations where present.
- Use `syncwave` (integer) for ArgoCD sync ordering.
- Use `enabled: true/false` booleans to toggle features and optional sub-charts.

### Template Conventions

- **ArgoCD annotations** are critical. Most resources use:
  - `argocd.argoproj.io/sync-wave: {{ .Values.syncwave | default <N> | quote }}`
  - `argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true,Validate=false`
  - `argocd.argoproj.io/hook: PostSync` (for post-sync jobs)
  - `argocd.argoproj.io/hook-delete-policy: BeforeHookCreation`
- The `helper-installplan-approver` chart is the exception: it uses **Helm hooks** (`helm.sh/hook`, `helm.sh/hook-weight`) because it runs in Terraform-driven Helm installs, not ArgoCD.
- Quote sync-wave values: `{{ .Values.syncwave | quote }}`.
- Always set sensible defaults using `| default`.
- Multi-document YAML is common (`---` separators), especially in app-of-apps templates that iterate with `{{ range }}`.

## Chart Categories and Patterns

### 1. Operator Charts (most common pattern)

Charts that install OpenShift operators follow a standard pattern using two helper sub-charts:

```yaml
# Chart.yaml
dependencies:
  - name: helper-operator
    version: ~1.1.0
    repository: https://rh-mobb.github.io/validated-pattern-helm-charts/
  - name: helper-status-checker
    version: 4.4.3
    repository: https://rh-mobb.github.io/validated-pattern-helm-charts/
    condition: helper-status-checker.enabled
```

```yaml
# values.yaml
helper-operator:
  operators:
    <operator-name>:
      enabled: true
      syncwave: '0'
      namespace:
        name: <namespace>
        create: false
      subscription:
        channel: stable
        approval: Manual
        operatorName: <operator-name>
        source: redhat-operators
        sourceNamespace: openshift-marketplace
      operatorgroup:
        create: true
        notownnamespace: true

helper-status-checker:
  enabled: true
  checks:
    - operatorName: <operator-name>
      subscriptionName: <operator-name>
      namespace:
        name: <namespace>
      serviceAccount:
        name: "openshift-operators-install-check"
```

When creating a new operator chart, follow this pattern. The chart's own templates contain only the operator's custom resources (CRDs instances, configs), not the Subscription or OperatorGroup.

### 2. App-of-Apps Charts

These iterate over a list from values (sourced from `cluster-config`) to generate ArgoCD `Application` resources:

```yaml
# templates/infrastructure.yaml
{{ range $infra := .Values.infrastructure }}
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: "{{ $teamName }}-{{ $infra.chart }}"
  ...
{{ end }}
```

### 3. Helper Charts

- `helper-operator`: Installs OLM operators (Subscription, OperatorGroup, Namespace).
- `helper-status-checker`: Kubernetes Job that polls until an operator's CSV is ready.
- `helper-installplan-approver`: Auto-approves InstallPlans using Helm hooks.

Do not modify helper charts unless you are changing shared operator installation behavior. Changes to helpers affect all dependent charts.

### 4. Bootstrap Charts

`cluster-bootstrap` is deployed by Terraform (not ArgoCD). It installs OpenShift GitOps and creates the initial ArgoCD ApplicationSets. It depends on `helper-installplan-approver` and `application-gitops`.

## Version Management (Critical)

**Every change to a chart MUST include a version bump in `Chart.yaml`.** The CI/CD pipeline will fail if the version already exists.

- **Patch** (1.2.3 -> 1.2.4): Bug fixes, documentation, minor template tweaks.
- **Minor** (1.2.3 -> 1.3.0): New features, new templates, backward-compatible value additions.
- **Major** (1.2.3 -> 2.0.0): Breaking changes to values schema or template output.

The `charts/update-helper-charts.sh` script can bulk-update the `helper-status-checker` dependency version across all operator charts and auto-bump their chart versions. Usage:

```bash
cd charts
./update-helper-charts.sh <new-helper-version> [patch|minor|major]
```

## CI/CD

### Pull Requests

The `pull-request.yml` workflow runs:
1. `ct list-changed --target-branch main` to detect changed charts.
2. `ct lint` on changed charts (Yamale schema validation + yamllint).

Before submitting a PR, validate locally:

```bash
helm lint ./charts/<chart-name>
helm template test ./charts/<chart-name>
```

If the chart has dependencies, update them first:

```bash
helm dependency update ./charts/<chart-name>
helm template test ./charts/<chart-name>
```

### Release (main branch)

The `update-index.yml` workflow runs on push to `main`:
1. Adds required Helm repositories (openshift-charts, bitnami, backstage, validated-pattern-helm-charts).
2. Runs `helm/chart-releaser-action` to package changed charts, create GitHub releases, and update the repository index.
3. `skip-existing: true` in `cr-config.yaml` prevents overwriting existing versions.

## Common Tasks

### Creating a New Operator Chart

1. Create `charts/<operator-name>/` with `Chart.yaml`, `values.yaml`, `README.md`, and `templates/`.
2. Add `helper-operator` and `helper-status-checker` as dependencies in `Chart.yaml`.
3. Configure the operator subscription in `values.yaml` under `helper-operator.operators.<name>`.
4. Configure readiness checks in `values.yaml` under `helper-status-checker.checks`.
5. Add custom resource templates (the operator's CRDs) in `templates/`.
6. Use ArgoCD sync-wave annotations on custom resources to ensure they deploy after the operator is ready.
7. Write a `README.md` documenting all values.
8. Run `helm lint` and `helm template` to validate.

### Modifying an Existing Chart

1. Make your template or values changes.
2. **Bump the version** in `Chart.yaml`.
3. Run `helm lint ./charts/<chart-name>` to validate.
4. Run `helm template test ./charts/<chart-name>` to verify rendered output.
5. If the chart has dependencies, run `helm dependency update` first.
6. Update the chart's `README.md` if values or behavior changed.

### Updating Helper Chart Versions Across Charts

Use the bulk-update script:

```bash
cd charts
./update-helper-charts.sh 4.5.0 patch
```

This updates the `helper-status-checker` dependency version and bumps the chart version for all operator charts listed in the script. After running, review the changes and commit.

## Important Rules

1. **Always bump `Chart.yaml` version** when changing any chart. CI will reject duplicate versions.
2. **Do not modify `.github/cr-config.yaml`** unless changing the Helm repository configuration.
3. **Do not commit `Chart.lock` or `*.tgz` files.** They are in `.gitignore`.
4. **Preserve ArgoCD annotation patterns.** Sync-wave ordering is critical for operator installation sequencing.
5. **Use helper charts for operators.** Do not create raw Subscription/OperatorGroup resources directly in operator chart templates.
6. **Keep values.yaml defaults safe.** Use empty strings or `false` for environment-specific values that must be overridden.
7. **Values for deployed clusters live in `cluster-config`, not here.** This repo contains only chart definitions and defaults.
8. **Test with cluster-config values** when possible:
   ```bash
   helm template <name> ./charts/<chart-name> -f ../cluster-config/<env>/<cluster>/<config>.yaml
   ```
9. **The `main` branch auto-releases.** Only merge when charts are ready for publication.
10. **README.md is required for every chart.** Include a description, values table, and usage examples.

## Gotchas

- The `app-of-apps-infrastructure` chart uses `apiVersion: v1` (not v2). This is intentional.
- Some charts use `approval: Manual` in their operator subscription. This requires the `helper-installplan-approver` or `helper-status-checker` (with `approver: true`) to auto-approve the InstallPlan.
- The `helper-installplan-approver` uses Helm hooks (`helm.sh/hook`), not ArgoCD hooks. This is because `cluster-bootstrap` is deployed by Terraform's Helm provider, not by ArgoCD.
- `cluster-config` repo is referenced by ArgoCD multi-source applications using `$values` path notation (e.g., `$values/nonprod/np-hub/infrastructure.yaml`).
- The `.gitignore` excludes `charts/*/` (nested chart dependencies) and `Chart.lock`. These are resolved at build time.
