# External Secrets Operator Chart

## Overview

The `external-secrets-operator` chart installs the OpenShift External Secrets Operator and configures AWS Secrets Manager access through IRSA. This is the preferred replacement for the Argo CD Vault Plugin (AVP) path.

## Recommended Usage (platform metadata)

Bootstrap publishes ConfigMap `rosa-platform-metadata` with `secretsManagerRoleArn` (see [platform-metadata-irsa.md](https://github.com/rh-mobb/validated-pattern-terraform-rosa/blob/main/docs/architecture/platform-metadata-irsa.md)). Prefer that over hardcoding account ARNs in cluster-config:

```yaml
infrastructure:
  - chart: external-secrets-operator
    targetRevision: 1.1.5
    namespace: external-secrets-operator
    values:
      platformMetadata:
        enabled: true
      secretStore:
        name: aws-secrets-manager
        region: ap-southeast-2
      target:
        enabled: false
```

A sync Job annotates `external-secrets-sa` from the ConfigMap.

## Legacy / break-glass

```yaml
values:
  serviceAccount:
    roleArn: arn:aws:iam::123456789012:role/test-rosa-secretsmanager-role-iam
```

## Important Values

- `platformMetadata.enabled`: Bind IRSA from bootstrap ConfigMap (preferred)
- `serviceAccount.roleArn`: Explicit IRSA ARN (optional if platform metadata enabled)
- `secretStore.region`: AWS region for Secrets Manager access
- `target.enabled`: When false, skip the Kuadrant `aws-credentials` ExternalSecret

## Notes

- IRSA-dependent resources are created when `serviceAccount.roleArn` **or** `platformMetadata.enabled` is set.
- AVP remains available for compatibility this release, but new application onboarding should prefer ESO with `plugin: false`.
