# autonode

Helm chart that installs sample **[Karpenter `NodePool`](https://karpenter.sh/)** resources for **ROSA HCP AutoNode**.

## Prerequisites

- Cluster has **AutoNode enabled** and a **`EC2NodeClass`** named **`default`** (or override `nodeClassRef` per pool).
- Chart installs **cluster-scoped** `NodePool` objects.
- `templates/NOTES.txt` prints scheduling hints for every configured NodePool label set and includes a ready-to-apply `Deployment` example using `nodeSelector: { autonode: "true" }`.

## Values

| Key | Description |
|-----|-------------|
| `enabled` | Master toggle for NodePools |
| `nodePools` | List of pools (`name`, `labels`, `instanceTypes`, `capacityTypes`, `nodeClassRef`) |

## Example

```bash
helm upgrade --install autonode . \
  --namespace default
```

For GitOps, install via Argo CD **Helm** source pointing at this chart with values appropriate for your cluster (instance types, labels).
