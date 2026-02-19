# Authorino Operator Helm Chart

This Helm chart deploys the Red Hat Authorino Operator on OpenShift.

## Overview

Authorino is a Kubernetes-native authorization service for API security. It provides:
- Policy-based authorization
- Integration with external identity providers
- Fine-grained access control
- API authentication and authorization

## Prerequisites

- OpenShift cluster
- ArgoCD or Helm installed
- Access to Red Hat Operator catalog

## Configuration

### Default Values

```yaml
subscription:
  name: authorino-operator
  namespace: openshift-operators
  channel: stable
  installPlanApproval: Automatic
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  startingCSV: authorino-operator.v1.2.3

syncwave: "1"
```

### Custom Values

You can override the default values by providing a custom values file or setting values in your infrastructure configuration.

## Installation

### Via ArgoCD (Recommended)

Add to your infrastructure.yaml:

```yaml
infrastructure:
  - chart: authorino-operator
    targetRevision: 0.1.0
    namespace: openshift-operators
    values:
      subscription:
        startingCSV: authorino-operator.v1.2.3
```

### Via Helm CLI

```bash
helm install authorino-operator . \
  --namespace openshift-operators \
  --set subscription.startingCSV=authorino-operator.v1.2.3
```

## Upgrade

To upgrade to a new version, update the `startingCSV` value and sync via ArgoCD or run:

```bash
helm upgrade authorino-operator . \
  --namespace openshift-operators \
  --set subscription.startingCSV=authorino-operator.vX.Y.Z
```

## Uninstallation

```bash
helm uninstall authorino-operator --namespace openshift-operators
```

## Version History

- **0.1.0**: Initial release with Authorino Operator v1.2.3
