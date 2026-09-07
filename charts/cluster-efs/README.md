# Cluster EFS Helm Chart

This Helm chart deploys the AWS EFS CSI Driver operator and configures Amazon Elastic File System (EFS) storage for OpenShift clusters. The chart provides shared, persistent storage capabilities using AWS EFS, enabling applications to access shared file systems across multiple pods and nodes. This chart is designed for deployment via ArgoCD and integrates with the rosa-hcp-dedicated-vpc infrastructure.

## Overview

The Cluster EFS chart enables Amazon EFS integration with OpenShift by deploying the AWS EFS CSI Driver operator and creating the necessary storage classes and configurations. EFS provides scalable, shared file storage that can be mounted by multiple pods simultaneously, making it ideal for applications requiring shared data access, content management systems, and distributed workloads.

**Preferred GitOps values** (no account ARNs in git):

```yaml
platformMetadata:
  enabled: true
```

Bootstrap publishes `efsCsiRoleArn` and `efsFileSystemId` on `rosa-platform-metadata`. A sync Job writes the CSI credentials Secret and `efs-sc` StorageClass. Explicit `roleArn` / `fileSystemId` remain for break-glass.

## Prerequisites

- OpenShift Container Platform 4.10 or later
- AWS EFS file system provisioned via Terraform
- IAM role with appropriate EFS permissions
- VPC security groups configured for EFS access (port 2049)
- ArgoCD deployment (underlying EFS infrastructure provisioned via Terraform)
- Sufficient cluster resources (see [Resource Requirements](#resource-requirements))

### Terraform Infrastructure Setup

This chart is designed to work with the EFS infrastructure provisioned by the rosa-hcp-dedicated-vpc project. The required AWS EFS resources are automatically created by the Terraform configuration in [`7.storage.tf`](/Users/redhat/rosa-hcp-dedicated-vpc/rosa-hcp-dedicated-vpc/terraform/7.storage.tf).

The Terraform file creates:

1. **EFS File System** (`aws_efs_file_system.rosa_efs`): 
   - KMS-encrypted EFS file system
   - Named with pattern: `{cluster_name}-rosa-efs`
   - Integrated with cluster VPC and subnets

2. **IAM Role** (`rosa_efs_csi_role_iam`): 
   - Configured with OIDC trust relationship for EFS CSI driver service accounts
   - Allows assumption by `system:serviceaccount:openshift-cluster-csi-drivers:aws-efs-csi-driver-operator`
   - Allows assumption by `system:serviceaccount:openshift-cluster-csi-drivers:aws-efs-csi-driver-controller-sa`

3. **IAM Policy** (`rosa_efs_csi_policy_iam`): 
   - Grants necessary EFS permissions:
     - `elasticfilesystem:DescribeAccessPoints`
     - `elasticfilesystem:DescribeFileSystems`
     - `elasticfilesystem:DescribeMountTargets`
     - `elasticfilesystem:CreateAccessPoint`
     - `elasticfilesystem:DeleteAccessPoint`
     - `elasticfilesystem:TagResource`

4. **KMS Key** (`aws_kms_key.efs`): 
   - Dedicated KMS key for EFS encryption
   - Integrated with IAM policies for CSI driver access

5. **Mount Targets**: 
   - EFS mount targets in each private subnet
   - Security group rules allowing NFS traffic (port 2049)

6. **Security Group Configuration**: 
   - Ingress rules for EFS access from cluster subnets
   - NFS protocol (TCP port 2049) access

To enable EFS infrastructure in your Terraform deployment, ensure the `enable-efs` variable is set to `true` in your cluster configuration file (e.g., `clusters/np-app-1.json`).

## Chart Dependencies

This chart depends on the following sub-charts:

- **helper-operator** (v1.1.0): Manages EFS CSI driver operator subscription and installation
- **helper-status-checker** (v4.1.2): Validates operator readiness and health

## Architecture

The chart deploys the following components:

### Core Components
- **AWS EFS CSI Driver Operator**: OpenShift operator for EFS CSI driver management
- **ClusterCSIDriver**: Cluster-level CSI driver configuration for EFS
- **StorageClass**: EFS storage class with dynamic provisioning capabilities
- **Cloud Credentials Secret**: AWS credentials for EFS access

### AWS Integration
- **IAM Role Integration**: Uses OpenShift service account token for AWS authentication
- **EFS Integration**: Direct integration with AWS Elastic File System
- **KMS Encryption**: Encrypted file system using dedicated KMS key
- **Multi-AZ Support**: Mount targets across multiple availability zones

## Installation

This chart is designed for deployment via ArgoCD as part of the GitOps workflow. The underlying EFS infrastructure is provisioned by Terraform.

### ArgoCD Deployment

In the rosa-hcp-dedicated-vpc project, the Cluster EFS chart is deployed via ArgoCD as part of the GitOps workflow, while the underlying EFS infrastructure is provisioned by Terraform.

The EFS infrastructure is created by the [`7.storage.tf`](/Users/redhat/rosa-hcp-dedicated-vpc/rosa-hcp-dedicated-vpc/terraform/7.storage.tf) file, and the chart is deployed through the GitOps pipeline with the necessary parameters.

#### ArgoCD Application Example

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cluster-efs
  namespace: openshift-gitops
  annotations:
    argocd.argoproj.io/sync-wave: '2'
spec:
  destination:
    namespace: openshift-cluster-csi-drivers
    server: https://kubernetes.default.svc
  project: default
  sources:
    - repoURL: https://rosa-hcp-dedicated-vpc.github.io/helm-repository/
      chart: cluster-efs
      targetRevision: 0.2.9
      helm:
        valueFiles:
        - $values/cluster-config/nonprod/np-app-1/infrastructure.yaml
        values: |
          appTeam: cluster-efs
    - repoURL: https://github.com/rosa-hcp-dedicated-vpc/rosa-hcp-dedicated-vpc.git
      targetRevision: HEAD
      ref: values
  syncPolicy:
    automated:
      prune: false
      selfHeal: true
    syncOptions:
    - ApplyOutOfSyncOnly=true
    - CreateNamespace=true
```

#### Terraform EFS Infrastructure

```hcl
# Enable EFS in your cluster configuration
variable "enable-efs" {
  description = "Enable EFS storage for the cluster"
  type        = bool
  default     = true
}

# EFS file system with encryption
resource "aws_efs_file_system" "rosa_efs" {
  encrypted  = true
  kms_key_id = aws_kms_key.efs[0].arn
  tags = {
    Name = "${var.cluster_name}-rosa-efs"
  }
}

# IAM role for EFS CSI driver
resource "aws_iam_role" "rosa_efs_csi_role_iam" {
  name = "${var.cluster_name}-rosa-efs-csi-role-iam"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${module.oidc_config_and_provider.oidc_endpoint_url}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${module.oidc_config_and_provider.oidc_endpoint_url}:sub" = [
              "system:serviceaccount:openshift-cluster-csi-drivers:aws-efs-csi-driver-operator",
              "system:serviceaccount:openshift-cluster-csi-drivers:aws-efs-csi-driver-controller-sa"
            ]
          }
        }
      }
    ]
  })
}
```

### Direct Helm Installation

```bash
# Add the repository
helm repo add rosa-hcp-dedicated-vpc https://rosa-hcp-dedicated-vpc.github.io/helm-repository/

# Install the chart
helm install cluster-efs rosa-hcp-dedicated-vpc/cluster-efs \
  --namespace openshift-cluster-csi-drivers \
  --create-namespace \
  --set roleArn="arn:aws:iam::123456789012:role/my-cluster-rosa-efs-csi-role-iam" \
  --set fileSystemId="fs-1234567890abcdef0"
```

## Configuration

### Required Values

Happy path: set `platformMetadata.enabled: true` and leave `roleArn` / `fileSystemId` empty (bootstrap ConfigMap).

| Parameter | Description | Required |
|-----------|-------------|----------|
| `platformMetadata.enabled` | Read `efsCsiRoleArn` / `efsFileSystemId` from `rosa-platform-metadata` | Preferred |
| `roleArn` | IAM role ARN for EFS CSI driver authentication | Break-glass only |
| `fileSystemId` | AWS EFS file system ID | Break-glass only |

### Helper Chart Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `helper-operator.enabled` | Enable operator installation helper | `true` |
| `helper-operator.operators.aws-efs-csi-driver-operator.subscription.channel` | Operator subscription channel | `stable` |
| `helper-operator.operators.aws-efs-csi-driver-operator.subscription.approval` | Install plan approval mode | `Manual` |
| `helper-status-checker.enabled` | Enable operator status checking | `true` |
| `helper-status-checker.approver` | Enable install plan approval | `true` |

### Storage Class Configuration

The chart creates an EFS storage class with the following configuration:

| Parameter | Description | Value |
|-----------|-------------|-------|
| `provisioner` | CSI driver provisioner | `efs.csi.aws.com` |
| `provisioningMode` | EFS provisioning mode | `efs-ap` (Access Points) |
| `directoryPerms` | Directory permissions for access points | `700` |
| `gidRangeStart` | Starting GID for access points | `1000` |
| `gidRangeEnd` | Ending GID for access points | `2000` |
| `basePath` | Base path for dynamic provisioning | `/dynamic_provisioning` |
| `allowVolumeExpansion` | Allow volume expansion | `true` |

### Example Production Values

```yaml
# Production configuration
roleArn: "arn:aws:iam::123456789012:role/prod-cluster-rosa-efs-csi-role-iam"
fileSystemId: "fs-0123456789abcdef0"

# Operator configuration
helper-operator:
  operators:
    aws-efs-csi-driver-operator:
      subscription:
        channel: stable
        approval: Automatic  # For production automation

# Status checker configuration
helper-status-checker:
  enabled: true
  approver: true
  checks:
    - operatorName: aws-efs-csi-driver-operator
      subscriptionName: aws-efs-csi-driver-operator
      namespace:
        name: openshift-cluster-csi-drivers
```

## Resource Requirements

### Minimum Requirements

- **CPU**: 100m for CSI driver components
- **Memory**: 128Mi for CSI driver components
- **Storage**: Minimal (EFS is external storage)

### Recommended for Production

- **CPU**: 200m for CSI driver components
- **Memory**: 256Mi for CSI driver components
- **Network**: Sufficient bandwidth for NFS traffic
- **EFS Performance**: Consider Provisioned Throughput for high-performance workloads

## Features

### Storage Capabilities
- **Shared Storage**: Multiple pods can mount the same EFS volume simultaneously
- **Dynamic Provisioning**: Automatic creation of EFS access points for PVCs
- **Persistent Storage**: Data persists beyond pod lifecycle
- **Cross-AZ Access**: Access EFS from pods in any availability zone
- **Scalable**: EFS scales automatically based on usage

### Security Features
- **Encryption**: Data encrypted at rest using KMS
- **Access Control**: POSIX permissions and access points
- **IAM Integration**: Uses OpenShift service account tokens for AWS authentication
- **Network Security**: NFS traffic secured within VPC

### Performance Options
- **General Purpose**: Standard EFS performance mode
- **Max I/O**: Higher levels of aggregate throughput and operations per second
- **Provisioned Throughput**: Consistent throughput independent of file system size
- **Intelligent Tiering**: Automatic cost optimization with infrequent access storage

## Post-Installation

### Verify Installation

```bash
# Check EFS CSI driver operator status
oc get csv -n openshift-cluster-csi-drivers | grep efs

# Check ClusterCSIDriver
oc get clustercsidriver efs.csi.aws.com

# Check storage class
oc get storageclass efs-sc

# Check EFS CSI driver pods
oc get pods -n openshift-cluster-csi-drivers | grep efs

# Verify cloud credentials secret
oc get secret aws-efs-cloud-credentials -n openshift-cluster-csi-drivers
```

### Test EFS Storage

```yaml
# test-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: efs-test-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-sc
  resources:
    requests:
      storage: 1Gi
---
# test-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: efs-test-pod
  namespace: default
spec:
  containers:
  - name: test-container
    image: registry.redhat.io/ubi8/ubi:latest
    command:
      - /bin/bash
      - -c
      - |
        echo "Testing EFS mount..." > /mnt/efs/test.txt
        cat /mnt/efs/test.txt
        sleep 3600
    volumeMounts:
    - name: efs-storage
      mountPath: /mnt/efs
  volumes:
  - name: efs-storage
    persistentVolumeClaim:
      claimName: efs-test-pvc
```

```bash
# Apply test resources
oc apply -f test-pvc.yaml
oc apply -f test-pod.yaml

# Check PVC status
oc get pvc efs-test-pvc

# Check pod status
oc get pod efs-test-pod

# Verify EFS mount
oc exec efs-test-pod -- df -h /mnt/efs
oc exec efs-test-pod -- ls -la /mnt/efs/
```

## Usage Examples

### Basic PVC with EFS

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-storage
  namespace: my-app
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-sc
  resources:
    requests:
      storage: 10Gi
```

### Multi-Pod Shared Storage

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shared-app
  namespace: my-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: shared-app
  template:
    metadata:
      labels:
        app: shared-app
    spec:
      containers:
      - name: app
        image: nginx:latest
        volumeMounts:
        - name: shared-data
          mountPath: /usr/share/nginx/html
      volumes:
      - name: shared-data
        persistentVolumeClaim:
          claimName: shared-storage
```

### StatefulSet with EFS

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: content-management
  namespace: my-app
spec:
  serviceName: content-management
  replicas: 2
  selector:
    matchLabels:
      app: content-management
  template:
    metadata:
      labels:
        app: content-management
    spec:
      containers:
      - name: cms
        image: wordpress:latest
        volumeMounts:
        - name: shared-content
          mountPath: /var/www/html/wp-content
  volumeClaimTemplates:
  - metadata:
      name: shared-content
    spec:
      accessModes:
        - ReadWriteMany
      storageClassName: efs-sc
      resources:
        requests:
          storage: 20Gi
```

## Troubleshooting

### Common Issues

#### EFS CSI Driver Operator Installation Fails
```bash
# Check subscription status
oc get subscription aws-efs-csi-driver-operator -n openshift-cluster-csi-drivers -o yaml

# Check install plan
oc get installplan -n openshift-cluster-csi-drivers

# Check operator logs
oc logs -n openshift-cluster-csi-drivers deployment/aws-efs-csi-driver-operator
```

#### PVC Stuck in Pending State
```bash
# Check PVC events
oc describe pvc <pvc-name> -n <namespace>

# Check storage class
oc describe storageclass efs-sc

# Check CSI driver pods
oc get pods -n openshift-cluster-csi-drivers | grep efs
oc logs -n openshift-cluster-csi-drivers deployment/efs-csi-controller
```

#### Mount Issues
```bash
# Check EFS mount targets
aws efs describe-mount-targets --file-system-id <file-system-id>

# Check security group rules
aws ec2 describe-security-groups --group-ids <security-group-id>

# Check pod events
oc describe pod <pod-name> -n <namespace>

# Check CSI driver logs
oc logs -n openshift-cluster-csi-drivers daemonset/efs-csi-node
```

#### AWS Authentication Issues
```bash
# Check cloud credentials secret
oc get secret aws-efs-cloud-credentials -n openshift-cluster-csi-drivers -o yaml

# Check IAM role trust relationship
aws iam get-role --role-name <efs-csi-role-name>

# Check OIDC provider configuration
aws iam list-open-id-connect-providers
```

### Logs and Diagnostics

```bash
# EFS CSI driver operator logs
oc logs -n openshift-cluster-csi-drivers deployment/aws-efs-csi-driver-operator

# EFS CSI controller logs
oc logs -n openshift-cluster-csi-drivers deployment/efs-csi-controller

# EFS CSI node driver logs
oc logs -n openshift-cluster-csi-drivers daemonset/efs-csi-node

# Check events
oc get events -n openshift-cluster-csi-drivers --sort-by='.lastTimestamp'

# Export configuration for support
oc get clustercsidriver efs.csi.aws.com -o yaml > efs-csi-config.yaml
```

## Performance Optimization

### EFS Performance Modes

1. **General Purpose** (Default):
   - Up to 7,000 file operations per second
   - Lower latency per operation
   - Suitable for most workloads

2. **Max I/O**:
   - Higher levels of aggregate throughput
   - Higher operations per second
   - Slightly higher latencies per operation

### Throughput Modes

1. **Bursting Throughput** (Default):
   - Throughput scales with file system size
   - Baseline performance with burst capability

2. **Provisioned Throughput**:
   - Consistent throughput independent of size
   - Additional cost for provisioned capacity

### Best Practices

- Use EFS Intelligent Tiering for cost optimization
- Consider EFS One Zone for single-AZ workloads
- Monitor EFS CloudWatch metrics
- Implement proper backup strategies
- Use appropriate directory permissions

## Upgrading

### Terraform Upgrade

Update the EFS infrastructure through Terraform:

```bash
# Update Terraform configuration
terraform plan
terraform apply
```

### Manual Helm Upgrade

```bash
# Update repository
helm repo update

# Upgrade release
helm upgrade cluster-efs rosa-hcp-dedicated-vpc/cluster-efs \
  --namespace openshift-cluster-csi-drivers \
  --reuse-values
```

## Uninstallation

### Manual Uninstallation

```bash
# Delete PVCs using EFS storage class (important!)
oc get pvc --all-namespaces | grep efs-sc
oc delete pvc <pvc-names> -n <namespaces>

# Uninstall Helm release
helm uninstall cluster-efs -n openshift-cluster-csi-drivers

# Clean up remaining resources
oc delete clustercsidriver efs.csi.aws.com
oc delete storageclass efs-sc
oc delete subscription aws-efs-csi-driver-operator -n openshift-cluster-csi-drivers
```

**Warning**: Ensure all PVCs using the EFS storage class are deleted before uninstalling the chart to prevent data loss and resource cleanup issues.

## Security Considerations

- **IAM Permissions**: Use least-privilege IAM roles for EFS access
- **Network Security**: Implement proper security group rules for NFS traffic
- **Encryption**: Enable encryption at rest and in transit
- **Access Control**: Use EFS access points for fine-grained access control
- **Monitoring**: Monitor EFS access patterns and performance metrics

## Best Practices

### Storage Management
- Use appropriate storage classes for different workload types
- Implement proper backup strategies for critical data
- Monitor EFS usage and costs regularly
- Use EFS Intelligent Tiering for cost optimization

### Security
- Regularly rotate IAM credentials
- Use dedicated service accounts for EFS access
- Implement proper RBAC controls
- Monitor EFS access logs

### Performance
- Choose appropriate EFS performance and throughput modes
- Monitor EFS CloudWatch metrics
- Optimize application I/O patterns for NFS
- Consider EFS caching solutions for high-performance workloads

## Support

- **AWS EFS Documentation**: [Amazon Elastic File System](https://docs.aws.amazon.com/efs/)
- **OpenShift Storage Documentation**: [OpenShift Container Storage](https://docs.openshift.com/container-platform/latest/storage/)
- **EFS CSI Driver**: [AWS EFS CSI Driver](https://github.com/kubernetes-sigs/aws-efs-csi-driver)

## Contributing

This chart is part of the rosa-hcp-dedicated-vpc project. Please refer to the main repository for contribution guidelines.

## License

This chart is licensed under the Apache License 2.0. See the LICENSE file for details.

## Changelog

### Version 0.5.0
- `platformMetadata.enabled` sync Job writes CSI credentials Secret and `efs-sc` StorageClass from `rosa-platform-metadata` (`efsCsiRoleArn`, `efsFileSystemId`)
- Explicit `roleArn` / `fileSystemId` remain for break-glass
- StorageClass uses `provisioningMode: efs-ap`

### Version 0.2.8
- Current stable release
- AWS EFS CSI Driver operator integration
- Dynamic provisioning with EFS access points
- KMS encryption support
- Multi-AZ mount target configuration
- Production-ready security configuration
- Comprehensive RBAC setup
