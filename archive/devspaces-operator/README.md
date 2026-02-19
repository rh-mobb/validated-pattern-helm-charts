# Dev Spaces Operator

## Overview

The **Dev Spaces Operator** Helm chart deploys the Red Hat OpenShift Dev Spaces Operator, which provides cloud-based development environments. This operator enables developers to create consistent, reproducible development workspaces directly in the browser.

## Introduction

Red Hat OpenShift Dev Spaces is based on the open-source Eclipse Che project and provides cloud-native development environments. The Dev Spaces Operator simplifies the deployment and management of development workspaces, providing:

- **Browser-Based IDEs**: Full development environments accessible via web browser
- **Consistent Environments**: Reproducible development setups across teams
- **Container-Based Workspaces**: Isolated, containerized development environments
- **Git Integration**: Direct integration with Git repositories
- **Plugin Ecosystem**: Extensible with VS Code extensions and plugins

## Prerequisites

- OpenShift cluster with cluster-admin privileges
- ArgoCD or OpenShift GitOps installed
- Sufficient cluster resources for development workspaces
- Container registry access for workspace images

## Deployment

This chart is deployed via **ArgoCD** as part of the GitOps infrastructure pattern.

### ArgoCD Application Example

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: devspaces-operator
  namespace: openshift-gitops
  annotations:
    argocd.argoproj.io/sync-wave: '1'
spec:
  destination:
    namespace: openshift-operators
    server: https://kubernetes.default.svc
  project: default
  sources:
    - repoURL: https://rosa-hcp-dedicated-vpc.github.io/helm-repository/
      chart: devspaces-operator
      targetRevision: 0.1.0
      helm:
        valueFiles:
        - $values/cluster-config/nonprod/np-app-1/infrastructure.yaml
        values: |
          appTeam: devspaces-operator
    - repoURL: https://github.com/rosa-hcp-dedicated-vpc/cluster-config.git
      targetRevision: HEAD
      ref: values
  syncPolicy:
    automated:
      prune: false
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - SkipDryRunOnMissingResource=true
```

## Configuration

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `operatorChannel` | Operator subscription channel | `stable` |
| `operatorNamespace` | Target namespace for operator | `openshift-operators` |
| `operatorInstallPlanApproval` | InstallPlan approval mode | `Automatic` |
| `helper-status-checker.enabled` | Enable status checking | `true` |
| `syncwave` | ArgoCD sync wave | `1` |

## Dependencies

This chart includes the following dependencies:

- **helper-operator** (~1.1.0): Manages operator subscription and installation
- **helper-status-checker** (~4.1.2): Validates operator deployment status

## Usage

After deployment, you need to create a CheCluster instance to set up the Dev Spaces environment:

### Basic CheCluster Configuration

```yaml
apiVersion: org.eclipse.che/v2
kind: CheCluster
metadata:
  name: devspaces
  namespace: openshift-devspaces
spec:
  components:
    cheServer:
      debug: false
      logLevel: INFO
    metrics:
      enable: true
  containerRegistry: {}
  devEnvironments:
    startTimeoutSeconds: 300
    secondsOfRunBeforeIdling: 1800
    maxNumberOfWorkspacesPerUser: 5
    containerBuildConfiguration:
      openShiftSecurityContextConstraint: container-build
    disableContainerBuildCapabilities: false
  gitServices: {}
  networking: {}
```

## Support

For issues and support:

- Check operator logs and CheCluster status
- Review Red Hat OpenShift Dev Spaces documentation
- Contact Red Hat support for enterprise customers

## Version History

| Version | Changes |
|---------|---------|
| 0.1.0 | Initial release with basic operator deployment |

