# maas-verify

Post-deploy smoke test for RHOAI Models-as-a-Service (MaaS). A PostSync Job runs after every sync and exits non-zero on failure, so problems show up on the Argo CD app.

## Checks

| Phase | Checks | Enabled by |
|---|---|---|
| 1 Infrastructure | Gateway `Programmed`; `postgres` and `maas-api` ready; Authorino ready; `/maas-api/health` 200 | always |
| 2 Model | Model pods running; MaaSModelRef `Ready`; MaaSAuthPolicy `Active` | always (`model.*`) |
| 3 API | `/maas-api/v1/models` non-empty; ephemeral key on `model.subscription`; inference 200 | always |
| 4 Auth enforcement | No key and invalid key both rejected with 401/403 | always |
| 5 External models | Per entry: MaaSModelRef `Ready`, ephemeral key on its subscription, real 5-token completion 200 | `externalModels[]` |
| 6 Telemetry | MaaSTenantConfig `spec.telemetry.enabled=true`; LokiStack `usage` Ready | `checkTelemetry.enabled` |

Phase 5 makes one real (5-token) request per external model to the provider.

## Values

| Key | Default | Description |
|---|---|---|
| `namespace` | `maas-verify` | Namespace for the Job |
| `image` | `ose-cli:latest` | Job image |
| `startupDelay` | `120` | Seconds to wait before checking |
| `maas.gatewayHost` | `""` | MaaS host (auto-detected from route/gateway when empty) |
| `maas.*Namespace`, `maas.gatewayName` | see values | Where platform components live |
| `model.name` / `subscription` / `id` | `simulated` / `simulated-free` / opt-125m | Self-hosted model under test |
| `externalModels[]` | `[]` | `{name, namespace, subscription?, id?}`; `id` is resolved from `/maas-api/v1/models` if omitted |
| `checkTelemetry.enabled` | `false` | Phase 6 |
| `checkTelemetry.maasNamespace` / `tenantConfigName` | `models-as-a-service` / `default-tenant` | Tenant config location |
| `checkTelemetry.monitoringNamespace` / `lokiStack` | `redhat-ods-monitoring` / `usage` | LokiStack location (`""` skips) |

## Example (`infrastructure.yaml`)

```yaml
  - chart: maas-verify
    targetRevision: 0.2.0
    namespace: maas-verify
    values:
      externalModels:
        - {name: gpt-4o-mini, namespace: external-models-openai, subscription: gpt-4o-mini-free}
        - {name: gemini-38-flash, namespace: external-models-gemini}
      checkTelemetry:
        enabled: true
```

## Reading results

```bash
oc logs job/maas-verify -n maas-verify
```

Each check prints `[PASS]` or `[FAIL]`, followed by a summary.
