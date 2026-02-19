# Virtualization Operator Helm Chart

This Helm chart deploys the OpenShift Virtualization (CNV) operator on OpenShift clusters.

## Overview

OpenShift Virtualization enables you to run and manage virtual machine workloads alongside container workloads on the same OpenShift cluster.

## Prerequisites

- OpenShift 4.14+ cluster
- Cluster admin privileges
- Sufficient cluster resources for virtualization workloads

## Installation

```bash
helm install virtualization-operator ./virtualization-operator
```

## Configuration

### Key Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `operator.startingCSV` | Starting CSV version | `kubevirt-hyperconverged-operator.v4.16.2` |
| `operator.channel` | Operator channel | `stable` |
| `namespace.name` | Target namespace | `openshift-cnv` |
| `hyperConverged.create` | Create HyperConverged resource | `true` |

### Example Custom Values

```yaml
operator:
  startingCSV: kubevirt-hyperconverged-operator.v4.16.3
  
hyperConverged:
  create: true
  
helper-status-checker:
  enabled: true
```

## Components

1. **Namespace**: Creates `openshift-cnv` namespace
2. **OperatorGroup**: Configures operator group for CNV
3. **Subscription**: Installs the operator from OperatorHub
4. **HyperConverged**: Main CNV configuration resource
5. **Status Checker**: Validates operator installation

## Sync Waves

- Wave 0: Namespace, OperatorGroup
- Wave 1: Subscription
- Wave 2: HyperConverged resource (after operator is ready)

## Features

- Live migration support
- Storage import capabilities
- Resource management
- Integration with OpenShift monitoring
- Proper security context configuration

## Troubleshooting

Check operator status:
```bash
oc get csv -n openshift-cnv
oc get hyperconverged -n openshift-cnv
oc get pods -n openshift-cnv
```

## License

Apache 2.0
