# maas-model

Deploys one self-hosted model on RHOAI as a KServe `LLMInferenceService` and publishes it through Models-as-a-Service (MaaS), with access control and rate-limit tiers. Deploy one instance per model, using a `name:` override in `infrastructure.yaml`.

## Resources by sync wave

| Wave | Resource | Purpose |
|---|---|---|
| -1 | Namespace (`createNamespace`) | Model namespace with gateway-access and dashboard labels |
| 1 | LLMInferenceService `<model.name>` | Model server pods (vLLM or simulator), attached to the MaaS gateway, auth required |
| 3 | MaaSModelRef | Publishes the model in the MaaS catalogue |
| 3 | MaaSAuthPolicy `<model>-access` | **Who may call the model** (`access`) |
| 3 | MaaSSubscription `<model>-<tier>` per tier | **Rate-limit and metering plans**; `owners` = who may create keys on the tier |

## Subscriptions and access (0.3.0+)

| Concept | Value | Effect |
|---|---|---|
| Access | `access.groups` / `access.users` | MaaSAuthPolicy subjects: who may call the model with any key. Must include every team that owns a tier |
| Tier | `subscriptions.<tier>` | One MaaSSubscription `<model>-<tier>` with `tokenLimit` per `tokenWindow` and a `priority` |
| Tier owners | `subscriptions.<tier>.owners` | Who may **create API keys** on that tier (default `system:authenticated`) |

API keys are bound to one subscription when created, and usage is metered per subscription. A tier per team (`owners: {groups: [<team>]}`) gives per-team quotas and chargeback.

```yaml
values:
  access:
    groups: [legal-team, system:authenticated]
  subscriptions:
    free:    {enabled: true, tokenLimit: 100,    tokenWindow: 1m, priority: 10}
    premium: {enabled: true, tokenLimit: 100000, tokenWindow: 1m, priority: 20}
    legal:   {enabled: true, tokenLimit: 50000,  tokenWindow: 1m, priority: 20,
              owners: {groups: [legal-team]}}
```

**Backward compatibility:** when `subscriptions` is empty, the legacy `subscription.free` / `subscription.premium` blocks render `<model>-free` / `<model>-premium` exactly as before 0.3.0.

## Values

| Key | Default | Description |
|---|---|---|
| `namespace` / `createNamespace` | `llm` / `true` | Model namespace |
| `governanceNamespace` | `models-as-a-service` | Namespace for MaaSAuthPolicy and MaaSSubscription |
| `gatewayRef.name` / `namespace` | `maas-default-gateway` / `openshift-ingress` | MaaS gateway the model attaches to |
| `model.name` / `displayName` / `description` | `simulated` / ... | Names used across all resources |
| `model.uri` / `modelName` / `replicas` | tiny-gpt2 / opt-125m / 1 | Model source |
| `model.container.*` | llm-d simulator | Image, command, args, env, resources |
| `model.gpu.enabled` / `count` | `false` / `1` | GPU toleration, requests, `/dev/shm`, longer probes |
| `access.groups` / `access.users` | `[system:authenticated]` / `[]` | Who may call the model |
| `subscriptions` | `{}` | Tier map (see above) |
| `subscription.free` / `premium` | 100 and 100000 tokens/min | Legacy tiers |

## Example (`infrastructure.yaml`)

```yaml
  - chart: maas-model
    name: maas-model-qwen25-3b
    targetRevision: 0.3.0
    namespace: llm
    values:
      createNamespace: false
      model:
        name: qwen25-3b
        uri: "hf://Qwen/Qwen2.5-3B-Instruct-GPTQ-Int4"
        modelName: qwen25-3b
        gpu: {enabled: true, count: 1}
      subscriptions:
        free:    {enabled: true, tokenLimit: 100,    tokenWindow: 1m, priority: 10}
        premium: {enabled: true, tokenLimit: 100000, tokenWindow: 1m, priority: 20}
```
