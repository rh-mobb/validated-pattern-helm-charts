# maas-alerting-additional-config (DEPRECATED)

This chart is **deprecated** and will move to `archive/` once existing clusters have migrated. Despite its name it never contained alerting. It held MaaS telemetry, usage logging and Limitador Redis, which now live in the right places:

| Feature | Old value | Now in |
|---|---|---|
| MaaS telemetry patch Job | `telemetry.*` | `rhai-observability` → `telemetry.*` |
| Usage logging (MinIO + LokiStack `usage`) | `usageLogging.*` | `rhai-observability` → `usageLogging.*` (adds optional ESO credentials) |
| Redis for Limitador | `redis.*` | `maas-additional-config` ≥ 0.3.0 → `redis.*` |
| Job image | `patchImage` | `jobImage` |

## Migration

1. In one cluster-config change: add `rhai-observability` with the same `telemetry` and `usageLogging` values, move `redis` (if used) to `maas-additional-config` ≥ 0.3.0, and remove this chart's entry.
2. Remove this Application **without cascading**. Child apps carry the Argo resources finalizer, so a plain delete would also delete the `minio-data` PVC and LokiStack:
   ```bash
   oc patch application cluster-config-maas-alerting-additional-config -n openshift-gitops \
     --type merge -p '{"metadata":{"finalizers":null}}'
   oc delete application cluster-config-maas-alerting-additional-config -n openshift-gitops
   ```
3. Sync `cluster-config-rhai-observability`. Resource names are identical, so it adopts the orphaned resources.
