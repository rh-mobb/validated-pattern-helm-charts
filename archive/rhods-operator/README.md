# RHODS Operator Helm Chart

A comprehensive Helm chart for deploying Red Hat OpenShift Data Science (RHODS) operator on OpenShift clusters. This chart is deployed via ArgoCD as part of the infrastructure stack to provide enterprise-grade AI/ML and data science capabilities.

## Overview

The RHODS Operator chart deploys Red Hat OpenShift Data Science (now known as Red Hat OpenShift AI), providing a comprehensive platform for data scientists and developers to develop, train, and serve machine learning models at scale. RHODS includes Jupyter notebooks, model serving capabilities, data science pipelines, and integrated AI/ML frameworks.

This chart uses the `helper-operator` and `helper-status-checker` dependency charts to ensure reliable operator deployment with automated InstallPlan approval and readiness verification. It also includes optional dependencies on `servicemesh-operator` and `serverless-operator` to provide enhanced capabilities for secure model serving and scalable ML workloads. The chart creates and configures a `DataScienceCluster` resource to enable all RHODS components with proper sync wave orchestration for ArgoCD deployments.

## Prerequisites

- OpenShift 4.12+ cluster
- ArgoCD/OpenShift GitOps operator installed
- Cluster admin privileges
- Sufficient cluster resources (minimum 16GB RAM, 8 CPU cores recommended)
- GPU nodes (optional, for accelerated workloads)
- Persistent storage for notebooks and models

## Installation

This chart is **deployed via ArgoCD** as part of the infrastructure stack. It is not intended for direct Helm installation.

### ArgoCD Deployment

The chart is deployed through the `app-of-apps-infrastructure` pattern as part of the cluster infrastructure:

```yaml
# Example from cluster-config/nonprod/np-app-1/infrastructure.yaml
infrastructure:
  - chart: rhods-operator
    targetRevision: 1.0.2
    namespace: redhat-ods-operator
    values:
      helper-operator:
        startingCSV: rhods-operator.2.22.1
```

### Example ArgoCD Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cluster-config-rhods-operator
  namespace: openshift-gitops
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  project: default
  source:
    repoURL: https://rosa-hcp-dedicated-vpc.github.io/helm-repository
    chart: rhods-operator
    targetRevision: 1.0.2
    helm:
      values: |
        helper-operator:
          startingCSV: rhods-operator.2.22.1
        openshiftAI:
          datasciencecluster:
            enabled: true
            name: default-dsc
  destination:
    namespace: redhat-ods-operator
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: false
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - ApplyOutOfSyncOnly=true
```

## Configuration

### Core Values

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `helper-operator.operators.rhods-operator.enabled` | Enable RHODS operator | `true` | ✅ |
| `helper-operator.operators.rhods-operator.namespace.name` | Operator namespace | `redhat-ods-operator` | ✅ |
| `helper-operator.operators.rhods-operator.subscription.channel` | Subscription channel | `stable` | ✅ |
| `helper-operator.operators.rhods-operator.subscription.approval` | InstallPlan approval | `Manual` | ✅ |
| `openshiftAI.datasciencecluster.enabled` | Enable DataScienceCluster | `true` | ✅ |

### DataScienceCluster Components

| Parameter | Description | Default |
|-----------|-------------|---------|
| `openshiftAI.datasciencecluster.spec.components.dashboard.managementState` | Dashboard component | `Managed` |
| `openshiftAI.datasciencecluster.spec.components.workbenches.managementState` | Workbenches component | `Managed` |
| `openshiftAI.datasciencecluster.spec.components.datasciencepipelines.managementState` | Pipelines component | `Managed` |
| `openshiftAI.datasciencecluster.spec.components.kserve.managementState` | KServe component | `Managed` |
| `openshiftAI.datasciencecluster.spec.components.modelmeshserving.managementState` | ModelMesh component | `Managed` |
| `openshiftAI.datasciencecluster.spec.components.codeflare.managementState` | CodeFlare component | `Managed` |
| `openshiftAI.datasciencecluster.spec.components.ray.managementState` | Ray component | `Managed` |

## Features

### 🧠 **AI/ML Development Platform**
- **Jupyter Notebooks**: Pre-configured data science environments with popular ML libraries
- **Workbenches**: Persistent development environments with GPU support
- **Model Development**: Integrated tools for model creation, training, and validation
- **Experiment Tracking**: Built-in experiment management and versioning

### 🚀 **Model Serving and Deployment**
- **KServe**: Kubernetes-native model serving with auto-scaling
- **ModelMesh**: Multi-model serving for efficient resource utilization
- **Inference Endpoints**: RESTful and gRPC model serving endpoints
- **A/B Testing**: Built-in support for model comparison and canary deployments

### 📊 **Data Science Pipelines**
- **Kubeflow Pipelines**: Workflow orchestration for ML pipelines
- **Pipeline Components**: Reusable components for common ML tasks
- **Experiment Runs**: Automated pipeline execution and tracking
- **Artifact Management**: Centralized storage for models and datasets

### ⚡ **Distributed Computing**
- **CodeFlare**: Distributed training and batch processing
- **Ray Integration**: Scalable distributed computing framework
- **GPU Acceleration**: Support for NVIDIA GPUs and specialized hardware
- **Auto-scaling**: Dynamic resource allocation based on workload demands

## Post-Installation Access

### Accessing the RHODS Dashboard

```bash
# Get the dashboard route
oc get route rhods-dashboard -n redhat-ods-applications

# Access via OpenShift console
# Navigate to: Networking > Routes > rhods-dashboard
```

## Troubleshooting

### Common Issues

#### DataScienceCluster Not Syncing
```bash
# Check DataScienceCluster status
oc describe datasciencecluster default-dsc -n redhat-ods-operator

# Check ArgoCD application sync status
oc get application cluster-config-rhods-operator -n openshift-gitops

# Verify PostSync hook completion
oc get jobs -n redhat-ods-operator | grep status-checker
```

#### Operator Installation Issues
```bash
# Check subscription status
oc get subscription rhods-operator -n redhat-ods-operator

# Check InstallPlan approval
oc get installplan -n redhat-ods-operator

# Check operator logs
oc logs -n redhat-ods-operator -l name=rhods-operator
```

### Validation Commands

```bash
# Verify operator installation
oc get csv -n redhat-ods-operator | grep rhods-operator

# Check DataScienceCluster status
oc get datasciencecluster -n redhat-ods-operator

# Verify component deployments
oc get pods -n redhat-ods-applications

# Access RHODS dashboard
oc get route rhods-dashboard -n redhat-ods-applications
```

## Related Documentation

- **[Red Hat OpenShift AI Documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed)**
- **[OpenDataHub Documentation](https://opendatahub.io/docs/)**
- **[Kubeflow Documentation](https://www.kubeflow.org/docs/)**

## Version History

| Version | Changes |
|---------|---------|
| 1.0.2 | Current stable version with DataScienceCluster PostSync hooks |
| 1.0.1 | Enhanced ArgoCD integration and sync wave support |
| 1.0.0 | Initial release with comprehensive component support |

## Maintainer

- **Name**: Paul Foster
- **Email**: pafoster@redhat.com
- **Team**: Platform Engineering

## License

This chart is part of the ROSA HCP Dedicated VPC project and follows the project's licensing terms.