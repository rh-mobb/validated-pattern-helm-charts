# cudn-bgp-routing-operator

Deploys the [CUDN BGP Routing Operator](https://github.com/jingczhang/rosa-bgp-operator) and optional `CUDNBgpConfig` / `CUDNBgpRouting` CRs.

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
    uri: https://github.com/jingczhang/rosa-bgp-operator.git
    ref: master
```

This creates:

- `ImageStream` `operator`
- `BuildConfig` (Docker strategy, `ConfigChange` trigger) → `ImageStreamTag operator:<image.tag>`
- Deployment image trigger so the manager rolls out when the tag is populated

Requires the cluster image registry (`configs.imageregistry.operator.openshift.io/cluster`) to be `Managed`. The first sync may show `ImagePullBackOff` on the manager until the build completes.

Default BuildConfig resources are `requests: 2 CPU / 4Gi`, `limits: 4 CPU / 8Gi` (needed for `go build -a` + aws-sdk). Override via `buildOperator.resources` if required.

Production clusters should leave `buildOperator.enabled: false` and point `image.repository` / `image.tag` at a released image.
