# maas-additional-config

Platform configuration that RHOAI Models-as-a-Service (MaaS) needs but RHOAI doesn't provide. Deploy one instance per cluster.

| Area | Resources | Why |
|---|---|---|
| Database | ExternalSecrets `postgres-creds` and `maas-db-config`, PVC, Deployment and Service `postgres` | maas-api stores API keys, subscriptions and usage in PostgreSQL |
| Authorino TLS | Job `maas-authorino-tls` (+ RBAC) | Annotates the Authorino authorization Service so service-ca issues the TLS cert Authorino expects when TLS is on |
| Limitador Redis | Namespace, Deployment and Service `redis`; Secret `kuadrant-system/redis-config` | Shared and consistent rate-limit counters (optional) |
| Dashboard | Job `maas-dashboard-config` (+ RBAC) | Turns on MaaS, GenAI Studio, external models and the observability dashboard in OdhDashboardConfig |

## Resources by sync wave

| Wave | Resource | Condition |
|---|---|---|
| -1 | Namespace `redis.namespace` | `redis.enabled` |
| 0 | ExternalSecrets `postgres-creds`, `maas-db-config` | always |
| 0 | SA/ClusterRole/ClusterRoleBinding `maas-authorino-tls` | `authorinoTls.enabled` |
| 1 | PVC `postgres-data` | always |
| 1 | Redis Deployment, Service, Secret `redis-config` | `redis.enabled` |
| PostSync 1 | Job `maas-authorino-tls` | `authorinoTls.enabled` |
| 2 | Deployment and Service `postgres` | always |
| 3 | SA/ClusterRole/ClusterRoleBinding `maas-dashboard-config` | `dashboardConfig.enabled` |
| PostSync 4 | Job `maas-dashboard-config` | `dashboardConfig.enabled` |

## Prerequisites

- `external-secrets-operator` with ClusterSecretStore `aws-secrets-manager`.
- An AWS Secrets Manager secret (`awsSecret.key`) with properties `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` and `DB_CONNECTION_URL`, listed in Terraform `additional_secrets`.
- `rhai-on-openshift-chart` with MaaS enabled (for `redhat-ai-gateway-infra`, `kuadrant-system` and OdhDashboardConfig).

## Values

| Key | Default | Description |
|---|---|---|
| `namespace` | `redhat-ods-applications` | PostgreSQL and Job namespace |
| `gatewayInfraNamespace` | `redhat-ai-gateway-infra` | Where maas-api reads `maas-db-config` |
| `image.repository` / `tag` | `rhel9/postgresql-16` / `latest` | PostgreSQL image |
| `resources` | 250m/512Mi → 1/1Gi | PostgreSQL resources |
| `storage.size` / `storageClass` | `20Gi` / `""` | PostgreSQL PVC |
| `secretStore.name` / `kind` | `aws-secrets-manager` / `ClusterSecretStore` | ESO store |
| `awsSecret.key` / `refreshInterval` | `""` / `1h` | AWS SM secret for DB credentials |
| `dashboardConfig.enabled` | `false` | Patch OdhDashboardConfig feature flags |
| `authorinoTls.enabled` / `namespace` / `certSecretName` | `false` / `kuadrant-system` / `authorino-server-cert` | Authorino serving cert |
| `redis.enabled` / `namespace` / `image` | `false` / `redis-limitador` / `rhel9/redis-7` | Limitador Redis |
| `jobImage` | `ose-cli:latest` | Image for config Jobs |

## Example (`infrastructure.yaml`)

```yaml
  - chart: maas-additional-config
    targetRevision: 0.3.0
    namespace: redhat-ods-applications
    values:
      secretStore: {name: aws-secrets-manager}
      awsSecret: {key: rhai/maas/postgres-creds}
      dashboardConfig: {enabled: true}
      authorinoTls: {enabled: true}
```

## Upgrading to 0.3.0

- **`userWorkloadMonitoring` removed.** `cluster-monitoring-config` is now owned by the `rhai-observability` chart. Rendering fails if `userWorkloadMonitoring.enabled` is still set. Deploy `rhai-observability` (`userWorkloadMonitoring.enabled: true`) first, then upgrade this chart and drop the key.
- **`redis` added**, moved from the deprecated `maas-alerting-additional-config`. Resource names are unchanged.

## Troubleshooting

| Symptom | Check |
|---|---|
| maas-api can't connect to the DB | `oc get externalsecret -n redhat-ai-gateway-infra maas-db-config`; the AWS SM key is in Terraform `additional_secrets` |
| Gateway auth fails with TLS errors | `oc logs job/maas-authorino-tls -n redhat-ods-applications`; `oc get secret authorino-server-cert -n kuadrant-system` |
| GenAI Studio / MaaS missing in the Dashboard | `oc logs job/maas-dashboard-config -n redhat-ods-applications` |
