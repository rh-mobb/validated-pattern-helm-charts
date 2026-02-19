# ACM Operator Helm Chart

This Helm chart deploys Red Hat Advanced Cluster Management (RHACM) for OpenShift, providing comprehensive multi-cluster management capabilities including cluster lifecycle management, application lifecycle management, governance, risk, and compliance (GRC), and observability across hybrid cloud environments.

## Overview

Red Hat Advanced Cluster Management for Kubernetes provides the tools and capabilities to address various challenges with managing multiple clusters and applications across hybrid cloud environments. This chart automates the deployment of RHACM components including the MultiClusterHub operator and its associated resources.

## Prerequisites

- OpenShift Container Platform 4.10 or later
- Cluster administrator privileges
- Sufficient cluster resources (see [Resource Requirements](#resource-requirements))
- ArgoCD or OpenShift GitOps (if using GitOps deployment)

## Chart Dependencies

This chart depends on the following sub-charts:

- **helper-operator** (v1.1.0): Manages operator subscription and installation
- **helper-status-checker** (v4.1.2): Validates operator readiness and health

## Installation

This chart is designed to be deployed using ArgoCD/OpenShift GitOps and includes ArgoCD-specific annotations for proper sync wave management and resource handling.

### ArgoCD Deployment

The chart includes built-in ArgoCD annotations:
- **Sync Wave**: Uses `argocd.argoproj.io/sync-wave` to ensure proper deployment order
- **Sync Options**: Includes `SkipDryRunOnMissingResource=true` for CRD handling
- **Pre-install Hooks**: Namespace creation uses Helm pre-install hooks

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: acm-operator
  namespace: openshift-gitops
  annotations:
    argocd.argoproj.io/compare-options: IgnoreExtraneous
spec:
  project: default
  source:
    repoURL: https://rosa-hcp-dedicated-vpc.github.io/helm-repository/
    chart: acm-operator
    targetRevision: "0.1.1"
    helm:
      values: |
        # Custom sync wave (default is 3)
        syncwave: 5
        
        # Additional configuration
        helper-operator:
          operators:
            acm-operator:
              subscription:
                approval: Manual
  destination:
    server: https://kubernetes.default.svc
    namespace: open-cluster-management
  syncPolicy:
    automated:
      prune: false
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - SkipDryRunOnMissingResource=true
      - ApplyOutOfSyncOnly=true
```

### Sync Wave Architecture

The chart uses the following sync wave strategy:

1. **Wave -10**: Namespace creation (pre-install hook)
2. **Wave 0**: Helper operator deployment and subscription
3. **Wave 1**: Operator installation and status checking
4. **Wave 3** (default): MultiClusterHub deployment
5. **Wave 5+**: Dependent applications and configurations

### Alternative: Helm CLI (Not Recommended)

While the chart can be installed via Helm CLI, it's designed for GitOps workflows:

```bash
# Not recommended - use ArgoCD instead
helm repo add rosa-hcp-dedicated-vpc https://rosa-hcp-dedicated-vpc.github.io/helm-repository/
helm install acm-operator rosa-hcp-dedicated-vpc/acm-operator \
  --namespace open-cluster-management \
  --create-namespace
```

## Configuration

### Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `syncwave` | ArgoCD sync wave for MultiClusterHub deployment | `3` |
| `namespaces` | List of namespaces to create | `[{name: "open-cluster-management"}]` |
| `helper-operator.enabled` | Enable operator installation helper | `true` |
| `helper-operator.operators.acm-operator.subscription.channel` | Operator subscription channel | `release-2.13` |
| `helper-operator.operators.acm-operator.subscription.approval` | Install plan approval mode | `Manual` |
| `helper-status-checker.enabled` | Enable operator status checking | `true` |
| `helper-status-checker.approver` | Enable install plan approval | `true` |

### MultiClusterHub Configuration

The chart creates a `MultiClusterHub` custom resource with the following default configuration:

#### Components

| Component | Enabled | Description |
|-----------|---------|-------------|
| `app-lifecycle` | ✅ | Application lifecycle management |
| `cluster-lifecycle` | ✅ | Cluster lifecycle management |
| `cluster-permission` | ✅ | Cluster permission management |
| `console` | ✅ | Web console integration |
| `grc` | ✅ | Governance, risk, and compliance |
| `insights` | ✅ | Cluster insights and analytics |
| `multicluster-engine` | ✅ | Core multicluster engine |
| `multicluster-observability` | ✅ | Observability across clusters |
| `search` | ✅ | Resource search capabilities |
| `submariner-addon` | ✅ | Network connectivity between clusters |
| `volsync` | ✅ | Volume replication |
| `cluster-backup` | ❌ | Cluster backup capabilities |
| `siteconfig` | ❌ | Site configuration management |
| `edge-manager-preview` | ❌ | Edge computing management (preview) |

### Example Custom Values

```yaml
# Custom sync wave for ArgoCD
syncwave: 5

# Additional namespaces
namespaces:
  - name: open-cluster-management
  - name: multicluster-engine
    labels:
      environment: production
    annotations:
      description: "Multicluster engine namespace"

# Operator configuration
helper-operator:
  operators:
    acm-operator:
      subscription:
        channel: release-2.14  # Use newer channel
        approval: Automatic    # Auto-approve install plans

# Status checker configuration
helper-status-checker:
  enabled: true
  approver: false  # Disable auto-approval
  checks:
    - operatorName: acm-operator
      subscriptionName: acm-operator
      namespace:
        name: open-cluster-management
```

## Resource Requirements

### Minimum Requirements

- **CPU**: 4 cores
- **Memory**: 8 GB RAM
- **Storage**: 20 GB available storage

### Recommended for Production

- **CPU**: 8+ cores
- **Memory**: 16+ GB RAM
- **Storage**: 50+ GB available storage
- **High Availability**: 3+ worker nodes

## Features

### Cluster Management
- **Cluster Discovery**: Automatically discover and import existing clusters
- **Cluster Provisioning**: Create new clusters on various cloud providers
- **Cluster Lifecycle**: Manage cluster upgrades, scaling, and decommissioning
- **Cluster Health**: Monitor cluster health and performance metrics

### Application Management
- **GitOps Integration**: Deploy applications using GitOps workflows
- **Multi-cluster Deployment**: Deploy applications across multiple clusters
- **Application Topology**: Visualize application relationships and dependencies
- **Subscription Management**: Manage application subscriptions and channels

### Governance & Compliance
- **Policy Management**: Define and enforce policies across clusters
- **Compliance Reporting**: Generate compliance reports and dashboards
- **Risk Assessment**: Identify and mitigate security risks
- **Audit Logging**: Comprehensive audit trails for all operations

### Observability
- **Metrics Collection**: Collect metrics from all managed clusters
- **Centralized Logging**: Aggregate logs from multiple clusters
- **Alerting**: Configure alerts for cluster and application issues
- **Dashboards**: Pre-built Grafana dashboards for monitoring

## Post-Installation

### Verify Installation

```bash
# Check operator status
oc get csv -n open-cluster-management

# Check MultiClusterHub status
oc get multiclusterhub -n open-cluster-management

# Check all pods are running
oc get pods -n open-cluster-management

# Access the console
oc get route multicloud-console -n open-cluster-management
```

### Initial Configuration

1. **Access the Console**: Navigate to the RHACM console URL
2. **Configure Authentication**: Set up identity providers if needed
3. **Import Clusters**: Import existing clusters or create new ones
4. **Set Up Policies**: Define governance policies for your environment
5. **Configure Observability**: Enable observability add-ons if required

## Troubleshooting

### Common Issues

#### Operator Installation Fails
```bash
# Check subscription status
oc get subscription acm-operator -n open-cluster-management -o yaml

# Check install plan
oc get installplan -n open-cluster-management

# Check operator logs
oc logs -n open-cluster-management -l name=multiclusterhub-operator
```

#### MultiClusterHub Not Ready
```bash
# Check MultiClusterHub status
oc describe multiclusterhub multiclusterhub -n open-cluster-management

# Check component status
oc get pods -n open-cluster-management
oc get pods -n multicluster-engine
```

#### Resource Constraints
```bash
# Check node resources
oc adm top nodes

# Check pod resource usage
oc adm top pods -n open-cluster-management
```

### Logs and Diagnostics

```bash
# Collect RHACM logs
oc logs -n open-cluster-management -l app=multiclusterhub-operator

# Check MultiClusterHub events
oc get events -n open-cluster-management --sort-by='.lastTimestamp'

# Export configuration for support
oc get multiclusterhub multiclusterhub -n open-cluster-management -o yaml > multiclusterhub-config.yaml
```

## Upgrading

### Helm Upgrade

```bash
# Update repository
helm repo update

# Upgrade the release
helm upgrade acm-operator rosa-hcp-dedicated-vpc/acm-operator \
  --namespace open-cluster-management
```

### Operator Channel Upgrade

To upgrade to a newer RHACM version, update the subscription channel in your values:

```yaml
helper-operator:
  operators:
    acm-operator:
      subscription:
        channel: release-2.14  # Update to newer channel
```

## Uninstallation

### Using Helm

```bash
# Uninstall the Helm release
helm uninstall acm-operator -n open-cluster-management

# Clean up remaining resources (if needed)
oc delete namespace open-cluster-management
```

### Manual Cleanup

```bash
# Remove MultiClusterHub
oc delete multiclusterhub multiclusterhub -n open-cluster-management

# Remove subscription
oc delete subscription acm-operator -n open-cluster-management

# Remove operator group
oc delete operatorgroup -n open-cluster-management --all

# Remove namespace
oc delete namespace open-cluster-management
```

## Security Considerations

- **RBAC**: The chart creates appropriate RBAC resources for operator functionality
- **Network Policies**: Consider implementing network policies for additional security
- **Certificate Management**: RHACM manages its own certificates by default
- **Secrets Management**: Sensitive data is stored in Kubernetes secrets
- **Audit Logging**: Enable audit logging for compliance requirements

## Support

- **Documentation**: [Red Hat Advanced Cluster Management Documentation](https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes/)
- **Community**: [OpenShift Commons](https://commons.openshift.org/)
- **Support**: Red Hat Support Portal for enterprise customers

## Contributing

This chart is part of the rosa-hcp-dedicated-vpc project. Please refer to the main repository for contribution guidelines.

## License

This chart is licensed under the Apache License 2.0. See the LICENSE file for details.

## Changelog

### Version 0.1.0
- Initial release
- Support for RHACM 2.13
- Integration with helper-operator and helper-status-checker
- Basic MultiClusterHub configuration
- ArgoCD sync wave support
