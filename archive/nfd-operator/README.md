# Node Feature Discovery Operator

This Helm chart deploys the Node Feature Discovery (NFD) Operator on OpenShift, which is required for GPU detection and labeling.

## Overview

Node Feature Discovery (NFD) detects hardware features available on each node in a Kubernetes cluster and advertises those features using node labels. This is essential for GPU workloads as it enables the NVIDIA GPU Operator to identify which nodes have GPU hardware.

## Components

This chart deploys:

- **NFD Operator**: Manages the lifecycle of NFD components
- **NodeFeatureDiscovery CR**: Configures NFD to detect GPU hardware
- **Helper Status Checker**: Ensures the operator is ready before proceeding

## Configuration

### Key Values

- `operatorName`: Name of the NFD operator (default: `nfd`)
- `operatorNamespace`: Namespace for NFD (default: `openshift-nfd`)
- `operatorChannel`: Operator channel (default: `stable`)
- `nodeFeatureDiscovery.enabled`: Enable NFD instance creation (default: `true`)

### GPU Detection

The chart is pre-configured to detect NVIDIA GPUs by:
- Scanning PCI devices for NVIDIA vendor ID (10de)
- Labeling nodes with GPU features
- Enabling the Node Feature API

## Deployment

This chart is designed to be deployed via ArgoCD with proper sync waves:

1. **Wave 0**: Namespace, OperatorGroup, Subscription
2. **Wave 2**: Status checker jobs
3. **Wave 3**: NodeFeatureDiscovery instance

## Dependencies

- **helper-status-checker**: Ensures operator readiness
- **Red Hat Operators catalog**: Source for the NFD operator

## Post-Installation

After NFD is deployed:
1. Nodes with GPUs will be labeled with hardware features
2. NVIDIA GPU Operator can detect and manage GPU resources
3. GPU workloads can be scheduled using node selectors

## Verification

Check NFD is working:

```bash
# Check NFD pods
oc get pods -n openshift-nfd

# Check node labels for GPU features
oc get nodes --show-labels | grep nvidia

# Verify NodeFeatureDiscovery instance
oc get nodefeaturediscovery -n openshift-nfd
```
