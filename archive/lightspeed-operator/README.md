# OpenShift Lightspeed Operator

This Helm chart deploys the Red Hat OpenShift Lightspeed Operator, which provides AI-powered assistance for OpenShift operations.

## Overview

OpenShift Lightspeed is an AI assistant that helps with OpenShift cluster management and troubleshooting tasks.

## Installation

This chart is designed to be deployed via ArgoCD as part of the GitOps workflow.

### Prerequisites

- OpenShift 4.14+
- Cluster administrator privileges

### Configuration

The chart uses manual installation approval by default. Key configuration options:

#### Operator Configuration
- `operatorNamespace`: Target namespace (default: openshift-lightspeed)
- `operatorChannel`: Operator channel (default: stable)
- `operatorInstallPlanApproval`: Installation approval mode (default: Manual)

#### OLSConfig Configuration
- `olsConfig.enabled`: Enable OLSConfig creation (default: true)
- `olsConfig.name`: Name of the OLSConfig resource (default: cluster)
- `olsConfig.llm.providers`: LLM provider configurations
- `olsConfig.ols.conversationCache`: Cache configuration for conversations
- `olsConfig.ols.logLevel`: Logging level (default: INFO)
- `olsConfig.ols.queryFilters`: Query filtering rules

#### API Key Configuration
You need to provide API keys for your LLM provider:
1. Base64 encode your API key
2. Update the secret template or provide via external secret management

## Dependencies

- helper-status-checker: Monitors operator installation status

## Resources Created

- Namespace: openshift-lightspeed
- OperatorGroup: Scoped to the lightspeed namespace
- Subscription: Manual approval for controlled deployment
- OLSConfig: Configuration for OpenShift Lightspeed AI assistant
- Secret: API keys for LLM provider (template provided)
- Status checker jobs: Monitor installation progress

## References

Based on the GitOps catalog example: [OpenShift Lightspeed Operator](https://github.com/sureshgaikwad/gitops-catalog/tree/main/operators/openshift-lightspeed)
