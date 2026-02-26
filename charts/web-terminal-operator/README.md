
# Web Terminal Operator Helm Chart

This Helm chart deploys the Web Terminal Operator on OpenShift clusters, providing browser-based terminal access directly from the OpenShift console. The chart is designed for deployment via ArgoCD and follows the standard operator installation pattern using `helper-operator` and `helper-status-checker`.

## Overview

The Web Terminal Operator adds a terminal launcher to the OpenShift web console, allowing users to run CLI commands (`oc`, `kubectl`, etc.) directly in the browser without a local terminal. The operator manages `DevWorkspace` custom resources that back each terminal session.

## Prerequisites

- OpenShift Container Platform 4.10 or later
- Cluster administrator privileges
- ArgoCD deployment (this chart is designed for GitOps deployment)

## Chart Dependencies

| Repository | Name | Version |
|------------|------|---------|
| https://rh-mobb.github.io/validated-pattern-helm-charts/ | helper-operator | ~1.1.0 |
| https://rh-mobb.github.io/validated-pattern-helm-charts/ | helper-status-checker | 4.4.3 |

## Installation

This chart is deployed via ArgoCD as part of the GitOps workflow.

### ArgoCD Application Example

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: web-terminal-operator
  namespace: openshift-gitops
  annotations:
    argocd.argoproj.io/sync-wave: '2'
spec:
  destination:
    namespace: openshift-operators
    server: https://kubernetes.default.svc
  project: default
  sources:
    - repoURL: https://rh-mobb.github.io/validated-pattern-helm-charts/
      chart: web-terminal-operator
      targetRevision: 1.0.0
      helm:
        valueFiles:
        - $values/cluster-config/nonprod/np-app-1/infrastructure.yaml
    - repoURL: https://github.com/your-org/cluster-config.git
      targetRevision: HEAD
      ref: values
  syncPolicy:
    automated:
      prune: false
      selfHeal: true
    syncOptions:
    - ApplyOutOfSyncOnly=true
```

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `helper-operator.operators.web-terminal.enabled` | Enable operator installation | `true` |
| `helper-operator.operators.web-terminal.syncwave` | ArgoCD sync wave for operator | `'0'` |
| `helper-operator.operators.web-terminal.subscription.channel` | Subscription channel | `fast` |
| `helper-operator.operators.web-terminal.subscription.approval` | InstallPlan approval mode | `Manual` |
| `helper-operator.operators.web-terminal.subscription.csv` | Starting CSV (set via cluster-config) | `""` |
| `helper-status-checker.enabled` | Enable operator readiness checks | `true` |
| `helper-status-checker.approver` | Enable InstallPlan auto-approval | `true` |

## Post-Installation

```bash
# Verify operator status
oc get csv -n openshift-operators | grep web-terminal

# Confirm operator pods are running
oc get pods -n openshift-operators -l app.kubernetes.io/part-of=web-terminal-operator
```

Once installed, a terminal icon appears in the OpenShift web console toolbar. Click it to launch a browser-based terminal session.

## Troubleshooting

```bash
# Check subscription status
oc get subscription web-terminal -n openshift-operators -o yaml

# Check install plan
oc get installplan -n openshift-operators

# Check operator logs
oc logs -n openshift-operators -l app.kubernetes.io/part-of=web-terminal-operator
```
