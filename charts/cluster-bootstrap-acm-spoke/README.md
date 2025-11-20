# Cluster Bootstrap Helm Chart

This Helm chart provides the foundational GitOps infrastructure for OpenShift clusters, bootstrapping the complete GitOps workflow including ArgoCD installation, initial repository configuration, and essential cluster components. This chart is designed for deployment via Terraform using Helm commands, serving as the cornerstone for cluster-level GitOps operations.

## Overview

The Cluster Bootstrap chart establishes the GitOps foundation for OpenShift clusters by deploying and configuring OpenShift GitOps (ArgoCD), setting up initial repositories, creating essential storage classes, and establishing the infrastructure needed for continuous deployment workflows. This chart serves as the entry point for all subsequent GitOps-managed cluster configurations.

## Prerequisites

- OpenShift Container Platform 4.10 or later
- Cluster administrator privileges
- AWS KMS key for EBS encryption (for storage class configuration)
- Terraform (for Terraform deployment)
- Access to required Git repositories and Helm repositories
- Sufficient cluster resources (see [Resource Requirements](#resource-requirements))

### Terraform Infrastructure Setup

This chart is designed to work with the infrastructure provisioned by the rosa-hcp-dedicated-vpc project. The chart is deployed automatically during cluster bootstrap via the [`bootstrap.tftpl`](https://github.com/rosa-hcp-dedicated-vpc/rosa-hcp-dedicated-vpc/blob/main/terraform/scripts/bootstrap.tftpl) script, which is executed by Terraform as part of the cluster provisioning process.

## Chart Dependencies

This chart depends on the following sub-charts:

- **helper-installplan-approver** (v0.1.0): Manages operator install plan approval
- **application-gitops** (v1.3.8): Deploys dedicated ArgoCD instance for application-level GitOps

## Architecture

The chart deploys the following components:

### Core GitOps Infrastructure
- **OpenShift GitOps Operator**: Subscription and configuration for cluster-level GitOps
- **ArgoCD Instance**: Cluster-level ArgoCD instance (`cluster-gitops`) with comprehensive configuration
- **ApplicationSet Controller**: Enables ApplicationSet functionality for advanced deployment patterns
- **RBAC Configuration**: Custom roles and bindings for GitOps operations

### Repository Integration
- **Initial Repositories**: Pre-configured Git and Helm repositories for cluster configuration
- **ArgoCD Applications**: Bootstrap applications for infrastructure and application namespace management
- **Vault Plugin**: AWS Secrets Manager integration for secure secret management

### Storage Configuration
- **KMS Storage Class**: Encrypted storage class using AWS KMS for enhanced security
- **Default Storage Class**: Configuration of default storage options

### Console Integration
- **Console Links**: Direct access to ArgoCD instances from OpenShift console
- **Custom Plugins**: ConfigMap plugins for enhanced ArgoCD functionality

## Installation

This chart is designed for deployment via Terraform, not ArgoCD.

### Terraform Deployment

In the rosa-hcp-dedicated-vpc project, the Cluster Bootstrap chart is deployed automatically during cluster bootstrap via the [`bootstrap.tftpl`](https://github.com/rosa-hcp-dedicated-vpc/rosa-hcp-dedicated-vpc/blob/main/terraform/scripts/bootstrap.tftpl) script. This script is executed by Terraform as part of the cluster provisioning process.

#### Bootstrap Script Deployment

The bootstrap script handles the deployment with the following command:

```bash
# Install cluster-bootstrap chart
echo "Installing/Upgrading cluster-bootstrap chart..."
helm upgrade --install cluster-bootstrap helm_repo_new/cluster-bootstrap \
  --version "${helm_chart_version}" \
  --insecure-skip-tls-verify \
  --set clusterName="${cluster}" \
  --set gitPath="${gitPath}" \
  --set domain="$domain" \
  --set csv="${gitops_csv}" \
  --set application-gitops.domain="$domain" \
  --set aws_region="${AWS_REGION}" \
  --set ecr_account="${ecr_account}" \
  --set helper-installplan-approver.ecr_account="${ecr_account}" \
  --set helper-installplan-approver.aws_region="${AWS_REGION}" \
  --set aws_kms_key_ebs="${aws_kms_key_ebs}"
```

#### Terraform Integration

The bootstrap script is called by Terraform through a `shell_script` resource that templates the script with the necessary variables:

```hcl
# Simplified example of how Terraform calls the bootstrap script
resource "shell_script" "cluster_bootstrap" {
  lifecycle_commands {
    create = templatefile(
      "./scripts/bootstrap.tftpl",
      {
        cluster                = var.cluster_name
        helm_chart            = "cluster-bootstrap"
        helm_chart_version    = "0.3.8"
        gitPath               = var.git_path
        gitops_csv            = var.gitops_csv
        AWS_REGION            = var.aws_region
        ecr_account           = var.ecr_account
        aws_kms_key_ebs       = var.aws_kms_key_ebs
        enable                = var.enable-gitops
      }
    )
  }
}
```



### Direct Helm Installation

```bash
# Add the repository
helm repo add rosa-hcp-dedicated-vpc https://rosa-hcp-dedicated-vpc.github.io/helm-repository/

# Install the chart
helm install cluster-bootstrap rosa-hcp-dedicated-vpc/cluster-bootstrap \
  --namespace openshift-operators \
  --create-namespace \
  --set clusterName="my-cluster" \
  --set domain="apps.cluster.example.com" \
  --set aws_kms_key_ebs="arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
```

## Configuration

### Core Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `clusterName` | Name of the OpenShift cluster | Required |
| `domain` | Cluster domain for console links and routing | Required |
| `aws_region` | AWS region for the cluster | Required |
| `aws_account` | AWS account ID | Required |
| `aws_kms_key_ebs` | AWS KMS key ARN for EBS encryption | Required |

### GitOps Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `csv` | ClusterServiceVersion for OpenShift GitOps operator | Required |
| `gitPath` | Git path for cluster configuration | `/` |

### ArgoCD Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `argocd.plugin.version` | ArgoCD Vault Plugin version | `1.18.1` |
| `argocd.plugin.AVP_TYPE` | Vault plugin type | `awssecretsmanager` |
| `argocd.initialRepositories` | Initial Git and Helm repositories | Pre-configured |
| `argocd.applications` | Bootstrap ArgoCD applications | Pre-configured |

### Namespace Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespaces` | List of namespaces to create | `[openshift-gitops, openshift-gitops-operator]` |

### Subscription Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `subscriptions[0].name` | OpenShift GitOps operator subscription name | `openshift-gitops-operator` |
| `subscriptions[0].channel` | Operator channel | `latest` |
| `subscriptions[0].installPlanApproval` | Install plan approval mode | `Manual` |

### Example Production Values

```yaml
# Production configuration
clusterName: "prod-cluster-01"
domain: "apps.prod.example.com"
aws_region: "us-east-1"
aws_account: "123456789012"
aws_kms_key_ebs: "arn:aws:kms:us-east-1:123456789012:key/prod-ebs-key-12345"

# GitOps configuration
csv: "openshift-gitops-operator.v1.10.1"
gitPath: "/clusters/prod"

# ArgoCD applications
argocd:
  applications:
  - name: cluster-config
    helmRepoUrl: https://rosa-hcp-dedicated-vpc.github.io/helm-repository/
    chart: app-of-apps-infrastructure
    project: cluster-config-project
    targetRevision: 0.0.4
    gitRepoUrl: https://github.com/my-org/cluster-config.git
    gitPathFile: /infrastructure.yaml
  - name: application-ns
    helmRepoUrl: https://rosa-hcp-dedicated-vpc.github.io/helm-repository/
    chart: app-of-apps-application
    project: application-ns-project
    targetRevision: 1.5.1
    gitRepoUrl: https://github.com/my-org/cluster-config.git
    gitPathFile: /applications-ns.yaml

# Application GitOps configuration
application-gitops:
  name: application-gitops
  gitopsNamespace: application-gitops
  domain: "apps.prod.example.com"
  argocd:
    initialRepositories:
    - url: https://github.com/my-org/app-configs
      type: git
    - url: https://my-org.github.io/helm-charts/
      type: helm
```

## Resource Requirements

### Minimum Requirements

- **CPU**: 2 cores total for ArgoCD components
- **Memory**: 4 GB RAM total for ArgoCD components
- **Storage**: 10 GB for repositories and cache

### Recommended for Production

- **CPU**: 6+ cores total for ArgoCD components
- **Memory**: 8+ GB RAM total for ArgoCD components
- **Storage**: 50+ GB for repositories and cache
- **High Availability**: Consider multiple replicas for production

## Features

### GitOps Foundation
- **OpenShift GitOps Integration**: Native OpenShift GitOps operator deployment
- **ArgoCD Configuration**: Comprehensive ArgoCD instance with production-ready settings
- **ApplicationSet Support**: Advanced deployment patterns with ApplicationSet controller
- **Multi-Repository Support**: Git and Helm repository integration

### Security & Access Control
- **RBAC Integration**: Custom roles and bindings for GitOps operations
- **OpenShift OAuth**: Seamless integration with OpenShift authentication
- **Vault Plugin Integration**: AWS Secrets Manager integration for secure secret management
- **Encrypted Storage**: KMS-encrypted storage classes for sensitive data

### Cluster Infrastructure
- **Storage Classes**: KMS-encrypted storage classes with appropriate defaults
- **Namespace Management**: Automated namespace creation and configuration
- **Console Integration**: Direct access to ArgoCD from OpenShift console
- **Operator Management**: Automated operator installation and approval

### Bootstrap Applications
- **Infrastructure Management**: Cluster-level infrastructure configuration via GitOps
- **Application Namespace Management**: Automated application namespace provisioning
- **Repository Integration**: Pre-configured repositories for cluster and application configs

## Post-Installation

### Verify Installation

```bash
# Check OpenShift GitOps operator status
oc get csv -n openshift-gitops-operator

# Check ArgoCD instance status
oc get argocd cluster-gitops -n openshift-gitops

# Check all pods are running
oc get pods -n openshift-gitops

# Check bootstrap applications
oc get applications -n openshift-gitops

# Access the ArgoCD console
oc get route cluster-gitops-server -n openshift-gitops
```

### Initial Configuration

1. **Access ArgoCD Console**: Navigate to the cluster-gitops ArgoCD console URL
2. **Verify Repositories**: Ensure initial repositories are configured and accessible
3. **Check Applications**: Verify bootstrap applications are synced and healthy
4. **Configure Additional Repositories**: Add any additional Git or Helm repositories
5. **Set Up Application Projects**: Configure ArgoCD projects for different teams/environments

## Usage Examples

### Adding New Repository

```yaml
# Add to argocd.initialRepositories in values
argocd:
  initialRepositories: |
    - name: my-app-configs
      type: git
      project: default
      url: https://github.com/my-org/app-configs.git
      insecure: false
    - name: my-helm-charts
      type: helm
      project: default
      url: https://my-org.github.io/helm-charts/
```

### Creating New Bootstrap Application

```yaml
# Add to argocd.applications in values
argocd:
  applications:
  - name: monitoring-stack
    helmRepoUrl: https://rosa-hcp-dedicated-vpc.github.io/helm-repository/
    chart: monitoring-payload
    project: infrastructure-project
    targetRevision: 1.0.0
    gitRepoUrl: https://github.com/my-org/cluster-config.git
    gitPathFile: /monitoring.yaml
```

### Custom Storage Class

```yaml
# The chart creates a KMS-encrypted storage class
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-csi-kms
parameters:
  encrypted: "true"
  type: gp3
  kmsKeyId: "{{ .Values.aws_kms_key_ebs }}"
provisioner: ebs.csi.aws.com
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

## Troubleshooting

### Common Issues

#### OpenShift GitOps Operator Installation Fails
```bash
# Check subscription status
oc get subscription openshift-gitops-operator -n openshift-gitops-operator -o yaml

# Check install plan
oc get installplan -n openshift-gitops-operator

# Check operator logs
oc logs -n openshift-gitops-operator deployment/gitops-operator-controller-manager
```

#### ArgoCD Instance Not Ready
```bash
# Check ArgoCD custom resource
oc describe argocd cluster-gitops -n openshift-gitops

# Check ArgoCD pods
oc get pods -n openshift-gitops

# Check ArgoCD server logs
oc logs -n openshift-gitops deployment/cluster-gitops-server
```

#### Bootstrap Applications Not Syncing
```bash
# Check application status
oc get applications -n openshift-gitops

# Describe specific application
oc describe application cluster-config -n openshift-gitops

# Check repository connectivity
oc logs -n openshift-gitops deployment/cluster-gitops-repo-server
```

#### Storage Class Issues
```bash
# Check storage classes
oc get storageclass

# Verify KMS key permissions
aws kms describe-key --key-id <kms-key-id>

# Check CSI driver status
oc get pods -n openshift-cluster-csi-drivers
```

### Logs and Diagnostics

```bash
# OpenShift GitOps operator logs
oc logs -n openshift-gitops-operator deployment/gitops-operator-controller-manager

# ArgoCD controller logs
oc logs -n openshift-gitops deployment/cluster-gitops-application-controller

# ArgoCD server logs
oc logs -n openshift-gitops deployment/cluster-gitops-server

# Repository server logs
oc logs -n openshift-gitops deployment/cluster-gitops-repo-server

# Check events
oc get events -n openshift-gitops --sort-by='.lastTimestamp'

# Export configuration for support
oc get argocd cluster-gitops -n openshift-gitops -o yaml > cluster-gitops-config.yaml
```

## Upgrading

### Terraform Upgrade

Update the chart version in your Terraform configuration:

```hcl
resource "shell_script" "cluster_bootstrap" {
  lifecycle_commands {
    create = templatefile(
      "./scripts/bootstrap.tftpl",
      {
        # ... other configuration ...
        helm_chart_version = "0.4.0"  # Update version
      }
    )
  }
}
```



### Manual Helm Upgrade

```bash
# Update repository
helm repo update

# Upgrade release
helm upgrade cluster-bootstrap rosa-hcp-dedicated-vpc/cluster-bootstrap \
  --namespace openshift-operators \
  --reuse-values
```

## Uninstallation

### Manual Uninstallation

```bash
# Uninstall Helm release
helm uninstall cluster-bootstrap -n openshift-operators

# Clean up ArgoCD applications (optional)
oc delete applications --all -n openshift-gitops

# Remove ArgoCD instance (optional)
oc delete argocd cluster-gitops -n openshift-gitops

# Remove operator subscription (optional)
oc delete subscription openshift-gitops-operator -n openshift-gitops-operator

# Remove namespaces (optional)
oc delete namespace openshift-gitops
oc delete namespace openshift-gitops-operator
```

## Security Considerations

- **RBAC**: The chart creates appropriate RBAC resources for GitOps operations
- **Encrypted Storage**: Uses KMS-encrypted storage classes for sensitive data
- **Secret Management**: Integrates with AWS Secrets Manager via ArgoCD Vault Plugin
- **Network Security**: Consider implementing network policies for additional security
- **Repository Access**: Ensure proper authentication and authorization for Git repositories

## Best Practices

### Repository Management
- Use separate repositories for cluster infrastructure and application configurations
- Implement proper branching strategies (GitFlow, GitHub Flow)
- Use environment-specific branches or directories

### ArgoCD Configuration
- Configure appropriate resource limits for ArgoCD components
- Use ArgoCD projects to organize applications by team or environment
- Implement proper RBAC policies for different user groups
- Monitor ArgoCD performance and resource usage

### Security
- Regularly update operator versions and chart versions
- Use encrypted storage for sensitive workloads
- Implement proper secret management practices
- Monitor and audit GitOps activities

## Support

- **OpenShift GitOps Documentation**: [Red Hat OpenShift GitOps Documentation](https://docs.openshift.com/container-platform/latest/cicd/gitops/understanding-openshift-gitops.html)
- **ArgoCD Documentation**: [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- **Community**: [ArgoCD Community](https://github.com/argoproj/argo-cd)

## Contributing

This chart is part of the rosa-hcp-dedicated-vpc project. Please refer to the main repository for contribution guidelines.

## License

This chart is licensed under the Apache License 2.0. See the LICENSE file for details.

## Changelog

### Version 0.3.8
- Current stable release
- OpenShift GitOps operator integration
- Comprehensive ArgoCD configuration with ApplicationSet support
- AWS Secrets Manager integration via Vault Plugin
- KMS-encrypted storage class support
- Bootstrap applications for infrastructure and application namespace management
- Production-ready RBAC and security configuration
