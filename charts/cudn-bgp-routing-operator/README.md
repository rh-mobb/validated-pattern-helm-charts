# cudn-bgp-routing-operator

Deploys the [BGP cloud connector](https://github.com/openshift/bgp-cloud-connector) (CUDN BGP operator) and optional `CUDNBgpConfig` / `CUDNBgpRouting` CRs.

Chart name is unchanged so existing app-of-apps / cluster-config entries keep working.

## Namespace

`app-of-apps-infrastructure` sets Argo CD `CreateNamespace=false`. This chart therefore creates `openshift-cudn-bgp-routing` when `createNamespace: true` (default).

## In-cluster image build (`buildOperator`)

For PoC clusters that do not yet pull a published operator image, enable an OpenShift `BuildConfig` that builds from git into the local registry path the deployment already expects:

```yaml
image:
  tag: dev

buildOperator:
  enabled: true
  git:
    uri: https://github.com/openshift/bgp-cloud-connector.git
    ref: main
```

This creates:

- `ImageStream` `operator`
- `BuildConfig` (Docker strategy, `ConfigChange` trigger) → `ImageStreamTag operator:<image.tag>`
- Deployment image trigger so the manager rolls out when the tag is populated

Requires the cluster image registry (`configs.imageregistry.operator.openshift.io/cluster`) to be `Managed`. The first sync may show `ImagePullBackOff` on the manager until the build completes.

Default BuildConfig resources are `requests: 2 CPU / 4Gi`, `limits: 4 CPU / 8Gi` (needed for `make build-operator` + aws-sdk). Override via `buildOperator.resources` if required.

Production clusters should leave `buildOperator.enabled: false` and point `image.repository` / `image.tag` at a released image.

## External Secrets (`externalSecret`) — Terraform → ESO → operator

Preferred path for ROSA HCP (issue [#51](https://github.com/rh-mobb/validated-pattern-terraform-rosa/issues/51)): Terraform publishes `{cluster}-bgp-config` to AWS Secrets Manager; this chart syncs it via External Secrets Operator and applies IRSA + `CUDNBgpConfig` `spec.platform: AWS` + `spec.aws`.

Prerequisites:

1. Terraform: `enable_route_server = true` and `enable_secrets_manager_iam = true`
2. `external-secrets-operator` chart with `serviceAccount.roleArn` set (and `target.enabled: false` unless you need the Kuadrant credentials ExternalSecret)
3. ClusterSecretStore `aws-secrets-manager`

```yaml
externalSecret:
  enabled: true
  remoteKey: bgp-bgp-config   # {cluster_name}-bgp-config
  secretStore: aws-secrets-manager

# Do not hardcode role ARN / region / routeServerIDs when externalSecret is enabled.
serviceAccount:
  annotations: {}

cudnBgpConfig:
  enabled: true
  platform: AWS
  localASN: 65001
  # aws.* omitted — owned by the bgp-config-apply Job
```

When `externalSecret.enabled=true`, Helm does **not** render `CUDNBgpConfig` (CRD requires `spec.platform` plus matching `spec.aws` or `spec.bgp.peerGroups`). An Argo **PostSync** Job waits for the ESO Secret, annotates the manager ServiceAccount, applies `CUDNBgpConfig`, and restarts the deployment (PostSync avoids blocking the manager Deployment on the Job).

If `externalSecret.remoteKey` is empty, the Job reads `bgpConfigSecretName` from bootstrap ConfigMap `rosa-platform-metadata` and creates the ExternalSecret (preferred — no cluster-specific secret name in git). See [platform-metadata-irsa.md](https://github.com/rh-mobb/validated-pattern-terraform-rosa/blob/main/docs/architecture/platform-metadata-irsa.md).
