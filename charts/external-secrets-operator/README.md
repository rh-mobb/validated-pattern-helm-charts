# External Secrets Operator Chart

## Overview

The `external-secrets-operator` chart installs the OpenShift External Secrets Operator and configures AWS Secrets Manager access through IRSA. This is the preferred replacement for the Argo CD Vault Plugin (AVP) path.

## Recommended Usage (platform metadata)

Bootstrap publishes ConfigMap `rosa-platform-metadata` with `secretsManagerRoleArn` (see [platform-metadata-irsa.md](https://github.com/rh-mobb/validated-pattern-terraform-rosa/blob/main/docs/architecture/platform-metadata-irsa.md)). Prefer that over hardcoding account ARNs in cluster-config:

```yaml
infrastructure:
  - chart: external-secrets-operator
    targetRevision: 1.1.7
    namespace: external-secrets-operator
    values:
      platformMetadata:
        enabled: true
      secretStore:
        name: aws-secrets-manager
      target:
        enabled: false
```

A sync Job annotates `external-secrets-sa` from `secretsManagerRoleArn`. Another Job waits for the ESO validating webhook, then applies `ClusterSecretStore` with `region` from `awsRegion` on the same ConfigMap. Do not hardcode `secretStore.region` or IRSA ARNs in portable recipes (ESO cannot read Secrets Manager until CSS already has a region, so region cannot come from `{cluster}-credentials` / `{cluster}-bgp-config`).

Explicit `secretStore.region` remains for break-glass; when set, Helm still renders ClusterSecretStore.

## Legacy / break-glass

```yaml
values:
  serviceAccount:
    roleArn: arn:aws:iam::123456789012:role/test-rosa-secretsmanager-role-iam
```

## Important Values

- `platformMetadata.enabled`: Bind IRSA and ClusterSecretStore region from bootstrap ConfigMap (preferred)
- `serviceAccount.roleArn`: Explicit IRSA ARN (optional if platform metadata enabled)
- `secretStore.region`: Optional explicit AWS region for ClusterSecretStore (break-glass; omit when platform metadata is enabled)
- `target.enabled`: When false, skip the Kuadrant `aws-credentials` ExternalSecret

## Notes

- IRSA-dependent resources are created when `serviceAccount.roleArn` **or** `platformMetadata.enabled` is set.
- AVP remains available for compatibility this release, but new application onboarding should prefer ESO with `plugin: false`.
