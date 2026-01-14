# cluster-bootstrap-acm-hub-registration

Helm chart to register spoke clusters with ACM hub.

## Overview

This chart deploys the necessary resources on the ACM hub cluster to register a spoke cluster:

1. **ManagedCluster** - Registers the spoke cluster with ACM
2. **ManagedClusterAddOn** - Enables the application-manager addon for GitOps integration
3. **GitOpsCluster** - Registers the spoke cluster's ArgoCD instance with the hub ArgoCD

## Installation

```bash
helm upgrade --install <cluster-name>-hub-registration ./cluster-bootstrap-acm-hub-registration \
  --namespace <cluster-name> \
  --create-namespace \
  --set clusterName="<cluster-name>" \
  --set environment="<environment>"
```

## Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `clusterName` | Name of the spoke cluster | `""` (required) |
| `environment` | Environment label (e.g., nonprod, prod) | `""` (required) |
| `managedCluster.hubAcceptsClient` | Auto-approve cluster registration | `true` |
| `managedCluster.leaseDurationSeconds` | Lease duration for cluster heartbeat | `60` |
| `applicationManager.enabled` | Enable application-manager addon | `true` |
| `applicationManager.installNamespace` | Namespace for addon on spoke | `open-cluster-management-agent-addon` |
| `gitopsCluster.enabled` | Enable GitOpsCluster registration | `true` |
| `gitopsCluster.argoNamespace` | ArgoCD namespace on hub | `openshift-gitops` |
| `gitopsCluster.placementName` | Placement resource name | `all-spoke-clusters` |

## Resources Created

### ManagedCluster
- Labels:
  - `acm: spoke` - For Placement selection
  - `environment: <environment>` - For ApplicationSet path resolution
  - `name: <clusterName>` - Cluster identifier

### ManagedClusterAddOn
- Enables the `application-manager` addon
- Required for ArgoCD cluster secret creation in Pull model

### GitOpsCluster
- Registers spoke ArgoCD with hub ArgoCD
- Uses the `all-spoke-clusters` Placement
- Enables ApplicationSet propagation to spoke

## Cleanup

To unregister a spoke cluster:

```bash
helm uninstall <cluster-name>-hub-registration -n <cluster-name>
```

This will remove the ManagedCluster, ManagedClusterAddOn, and GitOpsCluster resources.


