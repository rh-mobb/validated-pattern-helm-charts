# External Secrets Operator Chart

## Overview

The `external-secrets-operator` chart installs the OpenShift External Secrets Operator and configures AWS Secrets Manager access through IRSA. This is the preferred replacement for the Argo CD Vault Plugin (AVP) path.

## Recommended Usage

Use this chart from `app-of-apps-infrastructure` with `defaults.plugin: false` so Argo CD uses native Helm rendering.

```yaml
teamName: cluster-config
defaults:
  gitopsNamespace: openshift-gitops
  helmRepoUrl: https://rh-mobb.github.io/validated-pattern-helm-charts/
  path: charts
  plugin: false

infrastructure:
  - chart: external-secrets-operator
    targetRevision: 1.1.3
    namespace: external-secrets-operator
    values:
      serviceAccount:
        roleArn: arn:aws:iam::123456789012:role/test-rosa-secretsmanager-role-iam
```

## Important Values

- `namespace`: Namespace where the operator resources are installed
- `serviceAccount.roleArn`: IAM role ARN used by IRSA (for example the Task 2 role naming pattern `*-rosa-secretsmanager-role-iam`)
- `secretStore.region`: AWS region for Secrets Manager access
- `secretStore.secretName`: Source secret name in AWS Secrets Manager
- `target.namespace`: Namespace where the synced Kubernetes secret is created

## Notes

- If `serviceAccount.roleArn` is empty, this chart intentionally skips IRSA-dependent resources.
- AVP remains available for compatibility this release, but new application onboarding should prefer ESO with `plugin: false`.
