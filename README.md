# Validated Pattern Helm Charts

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

This repository contains Helm charts for deploying and managing OpenShift clusters on AWS using ROSA HCP (Red Hat OpenShift Service on AWS - Hosted Control Plane) with validated-pattern workflows.

**This repo is the GitOps arm of [validated-pattern-terraform-rosa](https://github.com/rh-mobb/validated-pattern-terraform-rosa)**, which uses Terraform to provision ROSA HCP clusters. After Terraform creates a cluster, the Terraform bootstrap step installs the `cluster-bootstrap` chart, which brings up OpenShift GitOps (ArgoCD) and deploys these Helm charts to configure the cluster—logging, storage, operators, team namespaces, and more.

## Architecture Overview

```mermaid
graph TD
    A[Terraform Infrastructure] -->|Deploys| B[cluster-bootstrap]
    B -->|Installs| C[OpenShift GitOps]
    B -->|Creates| D[ArgoCD Applications]
    
    D --> E[app-of-apps-infrastructure]
    D --> F[app-of-apps-application]
    
    E -->|Deploys| G[Infrastructure Charts]
    F -->|Deploys| H[app-of-apps-namespaces]
    H -->|Deploys| I[namespaces]
    
    G --> J[Operators & Platform Services]
    I --> K[Team Namespaces & Resources]
    
    L[Helper Charts] -.->|Support| G
    L -.->|Support| J
    
    style A fill:#e1f5fe
    style B fill:#f3e5f5
    style C fill:#fff3e0
    style D fill:#f3e5f5
    style E fill:#e8f5e8
    style F fill:#e8f5e8
    style G fill:#fff9c4
    style H fill:#e8f5e8
    style I fill:#fff9c4
```

## Chart Publishing & Release Process

### 📦 How to Publish Charts

Charts are automatically published when changes are committed to the `main` branch. The process is managed by GitHub Actions workflows located in the `.github/workflows/` directory.

#### **Version Management (Critical)**
⚠️ **IMPORTANT**: Always bump the chart version in `Chart.yaml` when making changes. Failing to update the version will cause GitHub Actions to fail during the release process.

```yaml
# charts/<chart-name>/Chart.yaml
apiVersion: v2
name: my-chart
description: Chart description
version: 1.2.3  # ← MUST be incremented for each change
```

#### **Publishing Workflow**
1. **Make Changes**: Update chart templates, values, or documentation
2. **Bump Version**: Increment version in `Chart.yaml` following [semantic versioning](https://semver.org/)
   - **Patch** (1.2.3 → 1.2.4): Bug fixes, documentation updates
   - **Minor** (1.2.3 → 1.3.0): New features, backward-compatible changes
   - **Major** (1.2.3 → 2.0.0): Breaking changes
3. **Commit & Push**: Commit changes to `main` branch
4. **Automatic Release**: GitHub Actions handles the rest

#### **GitHub Actions Workflow**
The `.github/workflows/` directory contains automated workflows that:

```
.github/workflows/
├── release.yml          # Main release workflow
├── lint-test.yml        # Chart linting and testing
└── pages-deploy.yml     # GitHub Pages deployment
```

**Release Process Flow**:
1. **Trigger**: Push to `main` branch with chart changes
2. **Lint & Test**: Validates chart syntax and structure
3. **Package**: Creates `.tgz` packages for changed charts
4. **Release**: Creates GitHub releases with chart packages
5. **Index Update**: Updates Helm repository index (`index.yaml`)
6. **Publish**: Deploys to GitHub Pages at `https://rh-mobb.github.io/validated-pattern-helm-charts/`

#### **Common Errors & Solutions**

**❌ Version Not Bumped Error**:
```
Error: Chart version 1.2.3 already exists
```
**Solution**: Increment the version in `Chart.yaml` before committing.

**❌ Invalid Version Format**:
```
Error: Version must follow semantic versioning
```
**Solution**: Use format `MAJOR.MINOR.PATCH` (e.g., `1.2.3`, not `v1.2.3` or `1.2`).

**❌ Chart Lint Failures**:
```
Error: Chart validation failed
```
**Solution**: Run local validation before committing:
```bash
helm lint ./charts/<chart-name>
helm template test ./charts/<chart-name>
```

#### **Verification**
After successful release, verify your chart is available:
```bash
# Add the Helm repository
helm repo add validated-pattern https://rh-mobb.github.io/validated-pattern-helm-charts/

# Update repository index
helm repo update

# Search for your chart
helm search repo validated-pattern/<chart-name>

# View available versions
helm search repo validated-pattern/<chart-name> --versions
```

---

## Chart Categories

### 🚀 Bootstrap Charts
**Purpose**: Foundation charts deployed by Terraform to establish GitOps infrastructure

| Chart | Version | Description | Deployment Method |
|-------|---------|-------------|-------------------|
| [cluster-bootstrap](./charts/cluster-bootstrap/README.md) | 0.4.0 | Core GitOps infrastructure and ArgoCD setup | Terraform via `bootstrap.tftpl` |
| [cluster-bootstrap-acm-spoke](./charts/cluster-bootstrap-acm-spoke/README.md) | 0.4.0 | ACM spoke cluster bootstrap variant | Terraform via `bootstrap.tftpl` |

**Key Features**:
- OpenShift GitOps operator installation
- ArgoCD instance configuration with vault plugin
- Initial repository setup (Git and Helm)
- KMS storage class creation
- Console integration and RBAC setup

---

### 🔄 App of Apps Charts
**Purpose**: GitOps orchestration using ArgoCD "App of Apps" pattern

| Chart | Version | Description | Deployment Method |
|-------|---------|-------------|-------------------|
| [app-of-apps-infrastructure](./charts/app-of-apps-infrastructure/README.md) | 0.1.2 | Infrastructure component orchestration | ArgoCD via cluster-bootstrap |
| [app-of-apps-application](./charts/app-of-apps-application/README.md) | 1.5.4 | Team application namespace orchestration | ArgoCD via cluster-bootstrap |
| [app-of-apps-namespaces](./charts/app-of-apps-namespaces/README.md) | 0.3.2 | Individual namespace deployment coordination | ArgoCD via app-of-apps-application |

**GitOps Flow**:
1. **Infrastructure Layer**: Deploys platform components (storage, logging, security)
2. **Application Layer**: Creates team-specific ArgoCD applications and projects
3. **Namespace Layer**: Deploys actual team namespaces with resources

**Configuration Sources**:
- `cluster-config/*/infrastructure.yaml` - Infrastructure component definitions
- `cluster-config/*/applications-ns.yaml` - Team application configurations
- `cluster-config/*/namespaces/*.yaml` - Individual team namespace configurations

---

### 🛠️ Helper Charts
**Purpose**: Utility charts that assist with operator installations and cluster operations

| Chart | Version | Description | Usage | Annotation Type |
|-------|---------|-------------|-------|-----------------|
| [helper-operator](./charts/helper-operator/README.md) | 1.0.26 | OpenShift operator installation automation | Sub-chart dependency | ArgoCD annotations |
| [helper-status-checker](./charts/helper-status-checker/README.md) | 1.0.7 | Operator readiness verification | Sub-chart dependency | ArgoCD annotations |
| [helper-installplan-approver](./charts/helper-installplan-approver/README.md) | 0.1.2 | InstallPlan approval automation | Standalone or sub-chart | Helm annotations |

**Annotation Differences**:
- **helper-operator & helper-status-checker**: Use ArgoCD annotations (`argocd.argoproj.io/sync-wave`, `argocd.argoproj.io/hook`) for GitOps deployment orchestration
- **helper-installplan-approver**: Uses Helm annotations (`helm.sh/hook`, `helm.sh/hook-weight`) for Terraform-driven Helm deployments

**Common Pattern**:
Most infrastructure charts use helper-operator + helper-status-checker as dependencies:
```yaml
dependencies:
  - name: helper-operator
    version: "1.0.26"
  - name: helper-status-checker  
    version: "1.0.7"
```

---

### 🏗️ Infrastructure Charts
**Purpose**: Platform-level components deployed via app-of-apps-infrastructure

#### Storage & Persistence
| Chart | Version | Description | Namespace |
|-------|---------|-------------|-----------|
| [cluster-efs](./charts/cluster-efs/README.md) | 0.3.0 | AWS EFS storage classes and CSI driver | openshift-cluster-csi-drivers |

#### Security & Compliance
| Chart | Version | Description | Namespace |
|-------|---------|-------------|-----------|
| [compliance-operator](./charts/compliance-operator/README.md) | 1.0.47 | OpenShift compliance scanning | openshift-compliance |
| [rhacs-operator](./charts/rhacs-operator/README.md) | 0.0.4 | Red Hat Advanced Cluster Security | rhacs-operator |
| [aws-privateca-issuer](./charts/aws-privateca-issuer/README.md) | 1.0.2 | AWS Private CA certificate issuer | cert-manager |

#### Logging & Monitoring
| Chart | Version | Description | Namespace |
|-------|---------|-------------|-----------|
| [cluster-logging](./charts/cluster-logging/README.md) | 0.4.0 | Centralized logging with CloudWatch | openshift-logging |

#### Management & Operations
| Chart | Version | Description | Namespace |
|-------|---------|-------------|-----------|
| [deploy-operator](./charts/deploy-operator/README.md) | 0.2.0 | Generic chart for lightweight operators (web-terminal, openshift-pipelines, devspaces, kiali, servicemesh, serverless, authorino) | openshift-operators |
| [acm-operator](./charts/acm-operator/README.md) | 0.2.0 | Multi-cluster management hub | open-cluster-management |
| [overprovisioning](./charts/overprovisioning/README.md) | 0.0.6 | Pod overprovisioning for autoscaling | overprovisioning |

**Deprecated** (use [deploy-operator](./charts/deploy-operator/README.md) instead): [tekton-pipelines](./charts/tekton-pipelines/README.md), [openshift-pipelines-operator](./charts/openshift-pipelines-operator/README.md), [devspaces-operator](./charts/devspaces-operator/README.md), [kiali-operator](./charts/kiali-operator/README.md), [servicemesh-operator](./charts/servicemesh-operator/README.md), [serverless-operator](./charts/serverless-operator/README.md), [authorino-operator](./charts/authorino-operator/README.md)

#### AI/ML Platform
| Chart | Version | Description | Namespace |
|-------|---------|-------------|-----------|
| [rhods-operator](./charts/rhods-operator/README.md) | 1.0.3 | Red Hat OpenShift Data Science | redhat-ods-operator |

#### Network & Ingress
| Chart | Version | Description | Namespace |
|-------|---------|-------------|-----------|
| [cluster-ingress](./charts/cluster-ingress/README.md) | 0.2.0 | Custom ingress controllers and certificates | openshift-ingress-operator |

---

### 👥 Application & Namespace Charts
**Purpose**: Team-level resources and namespace management

| Chart | Version | Description | Deployment Method |
|-------|---------|-------------|-------------------|
| [namespaces](./charts/namespaces/README.md) | 1.4.9 | Kubernetes namespace creation with governance | ArgoCD via app-of-apps-namespaces |
| [application-gitops](./charts/application-gitops/README.md) | 1.3.8 | Team-specific ArgoCD instance setup | ArgoCD or sub-chart dependency |

**Namespace Chart Features**:
- Namespace creation with labels and annotations
- Resource quotas and limits
- Network policies for security
- RBAC with Active Directory integration
- Service accounts for CI/CD pipelines
- ECR access automation via CronJobs

---

## Deployment Patterns

### 1. Terraform-Driven Bootstrap
```bash
# Infrastructure provisioning triggers bootstrap
terraform apply -target=shell_script.bootstrap
```

**Flow**: Terraform → cluster-bootstrap → OpenShift GitOps → ArgoCD Applications

### 2. GitOps-Driven Infrastructure
```yaml
# cluster-config/nonprod/np-hub/infrastructure.yaml
infrastructure:
  - chart: cluster-efs
    targetRevision: 0.3.0
    namespace: openshift-cluster-csi-drivers
```

**Flow**: app-of-apps-infrastructure → Infrastructure Charts → Platform Components

### 3. Team-Driven Applications
```yaml
# cluster-config/nonprod/np-hub/applications-ns.yaml
applications:
  - name: payments
    gitPath: nonprod/np-hub/namespaces/payments-1234.yaml
    gitopsCreate: true  # Creates team ArgoCD project
```

**Flow**: app-of-apps-application → app-of-apps-namespaces → namespaces → Team Resources

## Configuration Management

### Repository Structure
```
cluster-config/
├── nonprod/
│   ├── np-hub/
│   │   ├── infrastructure.yaml      # Infrastructure components
│   │   ├── applications-ns.yaml     # Team applications
│   │   └── namespaces/
│   │       ├── accounting-abcd.yaml # Team namespace config
│   │       └── payments-1234.yaml   # Team namespace config
│   ├── np-app-1/
│   ├── np-os-ai/
│   └── np-os-virt/
```

### Environment Separation
- **np-hub**: Hub cluster with ACM and shared services
- **np-app-1**: Application workload cluster
- **np-os-ai**: AI/ML workload cluster with RHODS
- **np-os-virt**: Virtualization workload cluster

## Security & RBAC

### Multi-Layered Security
1. **Infrastructure Level**: Platform operators and security tools
2. **Application Level**: Team ArgoCD projects with restricted access
3. **Namespace Level**: Resource quotas, network policies, RBAC

### Active Directory Integration
```yaml
appProject:
  adGroup: PFAUTHAD  # AD group for team access
  repos:
    - 'https://rh-mobb.github.io/validated-pattern-helm-charts'
    - 'https://github.com/rh-mobb/cluster-config.git'
```

### AWS Integration
- **IAM Roles**: Service-specific roles for EFS, CloudWatch, etc.
- **Secrets Manager**: Vault plugin integration for secure secret access
- **KMS**: Encrypted storage classes for data at rest

## Development & Testing

### Local Testing
```bash
# Test chart templating
helm template <chart-name> ./charts/<chart-name> \
  -f ../cluster-config/nonprod/np-hub/<config-file>.yaml

# Validate with cluster-config values
helm template test-app ./charts/app-of-apps-application \
  -f ../cluster-config/nonprod/np-hub/applications-ns.yaml
```

### Chart Dependencies
```bash
# Update chart dependencies
helm dependency update ./charts/<chart-name>

# Build chart packages
helm package ./charts/<chart-name>
```

## Troubleshooting

### Common Issues

1. **Chart Not Syncing**
   ```bash
   oc get applications -n openshift-gitops
   oc describe application <app-name> -n openshift-gitops
   ```

2. **Operator Installation Issues**
   ```bash
   oc get csv -A | grep <operator-name>
   oc get installplan -A
   ```

3. **RBAC Problems**
   ```bash
   oc get appprojects -n openshift-gitops
   oc describe appproject <project-name> -n openshift-gitops
   ```

### Verification Commands
```bash
# Check ArgoCD applications
oc get applications -n openshift-gitops

# Verify operators
oc get csv -A

# Check namespaces
oc get namespaces | grep -E "(accounting|payments)"

# Verify storage classes
oc get storageclass
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute.

### Chart Development Guidelines
1. **Use Helper Charts**: Leverage helper-operator and helper-status-checker for operators
2. **Follow Naming Conventions**: Use consistent naming patterns
3. **Include READMEs**: Comprehensive documentation for each chart
4. **Version Appropriately**: Semantic versioning for all changes
5. **Test Thoroughly**: Template testing with real cluster-config values

### Chart Structure
```
charts/<chart-name>/
├── Chart.yaml          # Chart metadata
├── README.md           # Comprehensive documentation
├── values.yaml         # Default configuration
└── templates/
    ├── _helpers.tpl    # Template helpers
    └── *.yaml          # Kubernetes resources
```

## Version Management

Charts are automatically versioned and tagged when changes are merged. The CI/CD pipeline:
1. Builds and packages charts
2. Creates GitHub releases with chart packages
3. Updates the Helm repository index
4. Publishes to GitHub Pages

## Support & Documentation

- **Individual Chart READMEs**: Detailed documentation for each chart
- **Architecture Diagrams**: Mermaid diagrams showing relationships
- **Configuration Examples**: Real-world cluster-config examples
- **Troubleshooting Guides**: Common issues and solutions

For specific chart documentation, see the individual README files in each chart directory.
