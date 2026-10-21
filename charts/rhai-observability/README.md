# rhai-observability

Cluster-level observability for RHAI (RHOAI + MaaS) clusters. Deploy **one instance per cluster**.

The chart owns the cluster-wide singletons and MaaS platform telemetry:

| Area | What it does | Why |
|---|---|---|
| User workload monitoring | `openshift-monitoring/cluster-monitoring-config` with `enableUserWorkload: true` | MaaS gateway, Limitador and model-serving metrics are only scraped with UWM on |
| MLflow | The cluster's single `MLflow` CR (must be named `mlflow`) | Trace and experiment store for `genai-workspace` instances (Playground and NemoGuardrails traces) |
| MaaS telemetry | PostSync Job patching `MaaSTenantConfig` (`telemetry.enabled`, `captureUser`) | Per-user and per-subscription token metrics: the basis for chargeback |
| MaaS usage logging | MinIO + bucket Job + LokiStack `usage`, and `spec.usageLogging` on the MaaS Config | Per-request usage records queryable in Loki |

The chart installs **no operators**. The OpenTelemetry, Tempo, Loki and Cluster Observability operators come from `rhai-on-openshift-chart` (`services.monitoring.dependencies`).

## Prerequisites

- `rhai-on-openshift-chart` with DSC `mlflowoperator: Managed` (for `mlflow.enabled`) and the Loki operator (for `usageLogging.enabled`).
- MaaS deployed (`aigateway.modelsAsAService: Managed`) for `telemetry.enabled`.
- `external-secrets-operator` with ClusterSecretStore `aws-secrets-manager` if `usageLogging.minio.secretStore.enabled`.

## Resources by sync wave

| Wave | Resource | Condition |
|---|---|---|
| 0 | ConfigMap `openshift-monitoring/cluster-monitoring-config` | `userWorkloadMonitoring.enabled` |
| 0 | `MLflow` `mlflow` (cluster-scoped) | `mlflow.enabled` |
| 0 | SA, ClusterRole and ClusterRoleBinding `maas-telemetry-config` | `telemetry.enabled` |
| 1 | PVC `minio-data`, Secret or ExternalSecret `minio-secret` | `usageLogging.enabled` |
| 2 | Deployment and Service `minio` | `usageLogging.enabled` |
| PostSync 3 | Job `minio-create-bucket` | `usageLogging.enabled` |
| 4 | LokiStack `usage` | `usageLogging.enabled` |
| PostSync 5 | Job `maas-telemetry-config` | `telemetry.enabled` |

## Values

| Key | Default | Description |
|---|---|---|
| `monitoringNamespace` | `redhat-ods-monitoring` | Namespace for the telemetry Job and usage-logging stack |
| `jobImage` | `ose-cli:latest` | Image for patch Jobs |
| `userWorkloadMonitoring.enabled` | `false` | Own `cluster-monitoring-config`. **Singleton:** only one Argo app may own it, and it replaces existing content |
| `mlflow.enabled` | `false` | Create the MLflow CR |
| `mlflow.workspaceLabel` | `rhai.mobb.io/genai-workspace` | Namespaces with `<label>=true` become MLflow workspaces |
| `mlflow.backendStoreUri` | `sqlite:////mlflow/mlflow.db` | Backend store |
| `mlflow.artifactsDestination` | `file:///mlflow/artifacts` | Artifact store |
| `mlflow.storageSize` | `5Gi` | MLflow PVC size |
| `telemetry.enabled` | `false` | Patch MaaSTenantConfig telemetry |
| `telemetry.captureUser` | `true` | Record the calling user on metrics |
| `telemetry.maasNamespace` | `models-as-a-service` | Namespace of the tenant config |
| `telemetry.tenantConfigName` | `default-tenant` | MaaSTenantConfig name |
| `usageLogging.enabled` | `false` | MinIO + LokiStack usage logging |
| `usageLogging.storageClassName` | `gp3-csi` | StorageClass for MinIO and Loki |
| `usageLogging.minio.rootUser` / `rootPassword` | `minio` / `minio123` | Demo-only plaintext credentials |
| `usageLogging.minio.secretStore.enabled` | `false` | Source credentials from AWS Secrets Manager via ESO |
| `usageLogging.minio.awsSecret.key` | `""` | AWS SM secret with properties `rootUser` and `rootPassword` |

## Example (`infrastructure.yaml`)

```yaml
  - chart: rhai-observability
    targetRevision: 0.1.0
    namespace: redhat-ods-monitoring
    values:
      userWorkloadMonitoring:
        enabled: true
      mlflow:
        enabled: true
      telemetry:
        enabled: true
      usageLogging:
        enabled: true
```

## Migrating from maas-additional-config / maas-alerting-additional-config

These resources used to live in `maas-additional-config` (UWM) and `maas-alerting-additional-config` (telemetry, usage logging). Resource names are unchanged, so the new app adopts them in place. Two Argo CD behaviours of `app-of-apps-infrastructure` matter:

- Child apps use `prune: false`. Removing a resource from one chart leaves it running until another app adopts it, so there is no UWM or usage-logging gap.
- Child apps carry `resources-finalizer.argocd.argoproj.io`. **Deleting the old Application cascades and deletes its resources**, including the `minio-data` PVC and the LokiStack. The parent also won't remove the Application on its own (`prune: false`).

Steps:

1. In one cluster-config change: add `rhai-observability` (same `telemetry` / `usageLogging` values, plus `userWorkloadMonitoring.enabled: true`), bump `maas-additional-config` to `>= 0.3.0` (drop `userWorkloadMonitoring`), and remove the `maas-alerting-additional-config` entry.
2. Remove the old Application **without cascading**, so its resources are orphaned instead of deleted:
   ```bash
   oc patch application cluster-config-maas-alerting-additional-config -n openshift-gitops \
     --type merge -p '{"metadata":{"finalizers":null}}'
   oc delete application cluster-config-maas-alerting-additional-config -n openshift-gitops
   ```
3. Sync `cluster-config-rhai-observability`. It adopts the ConfigMap, PVC, MinIO and LokiStack.

Redis for Limitador moved to `maas-additional-config` (`redis.enabled`), not here.

## Phase 2 (planned)

- Platform tracing: enable `services.monitoring.dsci.traces` (and `metrics`) in `rhai-on-openshift-chart`, so the RHOAI operator builds Tempo, OpenTelemetry and a MonitoringStack.
- `otelCollector.enabled`: an optional collector sending GenAI traces to both MLflow and Tempo.
- MaaS PrometheusRules, ServiceMonitors and dashboards.

## Troubleshooting

| Symptom | Check |
|---|---|
| MLflow CR rejected | Name must be `mlflow`; only one per cluster. `oc get mlflow` |
| Namespace not visible as an MLflow workspace | `oc get ns <ns> --show-labels`: needs `rhai.mobb.io/genai-workspace=true` |
| LokiStack not Ready | `oc get lokistack usage -n redhat-ods-monitoring -o yaml`; check the bucket Job logs and the `minio-secret` keys |
| Telemetry not applied | `oc logs job/maas-telemetry-config -n redhat-ods-monitoring`. "not found" means the MaaS CRs didn't exist yet; re-sync |
