# deploy-operator

## Overview

The **deploy-operator** chart is a generic wrapper that installs multiple lightweight OLM operators (Subscription only, no operands) from a single chart instance. It uses [helper-operator](../helper-operator/README.md) and [helper-status-checker](../helper-status-checker/README.md) to deploy operators declared in values.

**Lightweight operators** are those that only need a Subscription—no custom resources (operands) in the chart. Operands (e.g., CheCluster, NodeFeatureDiscovery) are typically created separately in cluster-config or other Applications.

## Presets

| Operator | Key | Package name | Approval |
|----------|-----|--------------|----------|
| Web Terminal | web-terminal | web-terminal | Automatic |
| OpenShift Pipelines (Tekton) | openshift-pipelines-operator-rh | openshift-pipelines-operator-rh | Manual |
| Dev Spaces | devspaces | devspaces | Automatic |
| Kiali | kiali-ossm | kiali-ossm | Manual |
| Service Mesh | servicemeshoperator | servicemeshoperator | Manual |
| Serverless (Knative) | serverless-operator | serverless-operator | Manual |
| Authorino | authorino-operator | authorino-operator | Automatic |

## Prerequisites

- OpenShift cluster
- ArgoCD or OpenShift GitOps installed
- Sufficient cluster resources for operators

## Deployment

This chart is deployed via **ArgoCD** as part of the app-of-apps-infrastructure pattern.

### Enabling operators

Override values from cluster-config to enable operators:

```yaml
# infrastructure.yaml - enable web-terminal and openshift-pipelines
- chart: deploy-operator
  targetRevision: 0.2.0
  namespace: openshift-operators
  values:
    helper-operator:
      operators:
        web-terminal:
          enabled: true
        openshift-pipelines-operator-rh:
          enabled: true
    helper-status-checker:
      approver: true
      checks:
        - operatorName: web-terminal
          subscriptionName: web-terminal
          namespace:
            name: openshift-operators
          serviceAccount:
            name: openshift-operators-install-check
        - operatorName: openshift-pipelines-operator-rh
          subscriptionName: openshift-pipelines-operator-rh
          namespace:
            name: openshift-operators
          serviceAccount:
            name: openshift-operators-install-check
```

### Check convention

For each enabled operator, add a corresponding entry to `helper-status-checker.checks`. The check verifies the operator CSV is ready before dependent resources deploy. When an operator uses Manual InstallPlan approval, set `helper-status-checker.approver: true` so the status checker can approve pending InstallPlans.

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `helper-operator.operators.<name>.enabled` | Enable operator | `false` |
| `helper-operator.operators.<name>.subscription.channel` | OLM channel | varies |
| `helper-operator.operators.<name>.subscription.approval` | InstallPlan approval | `Automatic` or `Manual` |
| `helper-status-checker.approver` | Auto-approve Manual InstallPlans | `true` |
| `helper-status-checker.checks` | List of operator readiness checks | `[]` |
| `syncwave` | ArgoCD sync wave | `1` |

## Migration from standalone charts

### tekton-pipelines / openshift-pipelines-operator

Both charts are deprecated. Use deploy-operator with `helper-operator.operators.openshift-pipelines-operator-rh.enabled: true`.

### devspaces-operator, kiali-operator, servicemesh-operator, serverless-operator, authorino-operator

These charts are deprecated. Use deploy-operator with the corresponding operator key enabled (e.g., `helper-operator.operators.devspaces.enabled: true`). See the Presets table above for operator keys.

## Dependencies

- **helper-operator** (~1.1.0): Manages operator Subscription and optional OperatorGroup/Namespace
- **helper-status-checker** (~4.4.3): Validates operator deployment status and approves InstallPlans when `approver: true`

## Support

For operator-specific issues, see the operator documentation (Web Terminal, OpenShift Pipelines).
