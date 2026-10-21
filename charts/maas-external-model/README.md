# maas-external-model

Exposes an external model provider (OpenAI, Gemini, Bedrock, Anthropic, Azure OpenAI) through RHOAI Models-as-a-Service (MaaS). Deploy one instance per external model, using a `name:` override in `infrastructure.yaml`.

Consumers never see the provider key. They call the MaaS gateway with a **MaaS API key** issued against one of this model's subscriptions. MaaS authenticates the key, rate-limits it and meters usage, then forwards the request to the provider with the provider key.

```
app / NemoGuardrails ──(MaaS API key)──► MaaS gateway ──(provider key, from AWS SM)──► api.openai.com
                                          Authorino: key valid? caller in access list?
                                          Limitador: subscription token limit
```

## Resources by sync wave

| Wave | Resource | Purpose |
|---|---|---|
| -1 | Namespace (`createNamespace`) | Holds provider resources; `maas.opendatahub.io/gateway-access` label |
| 0 | ExternalSecret `<provider.secret.name>` (`secretStore.enabled`) | Provider API key from AWS Secrets Manager |
| 1 | ExternalProvider | Provider endpoint and key reference |
| 2 | ExternalModel | MaaS model mapped to the provider's `targetModel` |
| 3 | MaaSModelRef | Publishes the model in the MaaS catalogue |
| 3 | MaaSAuthPolicy `<model>-access` | **Who may call the model** (`access`) |
| 3 | MaaSSubscription `<model>-<tier>` per tier | **Rate-limit and metering plans**; `owners` = who may create keys on the tier |

## Subscriptions and access (0.2.0+)

| Concept | Value | Effect |
|---|---|---|
| Access | `access.groups` / `access.users` | MaaSAuthPolicy subjects: who may call the model with any key. Must include every team that owns a tier |
| Tier | `subscriptions.<tier>` | One MaaSSubscription `<model>-<tier>` with `tokenLimit` per `tokenWindow` and a `priority` |
| Tier owners | `subscriptions.<tier>.owners` | Who may **create API keys** on that tier (default `system:authenticated`) |

API keys are bound to one subscription when created, and usage is metered per subscription. Giving each team its own tier with `owners: {groups: [<team>]}` therefore gives per-team quotas and chargeback.

```yaml
values:
  access:
    groups: [support-team, legal-team]
  subscriptions:
    free:       {enabled: true, tokenLimit: 100,   tokenWindow: 1m, priority: 10}
    guardrails: {enabled: true, tokenLimit: 20000, tokenWindow: 1m, priority: 15}   # genai-workspace judge
    support:    {enabled: true, tokenLimit: 50000, tokenWindow: 1m, priority: 20,
                 owners: {groups: [support-team]}}
```

Creating a key on a tier (the caller must be in the tier's `owners`):

```bash
curl -sk -X POST "https://<maas-host>/maas-api/v1/api-keys" \
  -H "Authorization: Bearer $(oc whoami -t)" -H "Content-Type: application/json" \
  -d '{"name":"guardrails-demo","subscription":"gpt-4o-mini-guardrails","expiresIn":"720h"}'
```

**Backward compatibility:** when `subscriptions` is empty, the legacy `subscription` block renders `<model>-free` exactly as before 0.2.0. Existing keys on `<model>-free` keep working when you switch to `subscriptions.free`, because the name is unchanged.

## Values

| Key | Default | Description |
|---|---|---|
| `namespace` / `createNamespace` | `external-models` / `true` | Provider namespace |
| `governanceNamespace` | `models-as-a-service` | Namespace for MaaSAuthPolicy and MaaSSubscription |
| `provider.name` / `type` / `endpoint` / `secret.name` | `""` | Provider definition |
| `model.name` / `displayName` / `description` / `targetModel` / `apiFormat` / `path` | see values | Model mapping |
| `access.groups` / `access.users` | `[system:authenticated]` / `[]` | Who may call the model |
| `subscriptions` | `{}` | Tier map (see above) |
| `subscription.*` | enabled, 10000/1h, priority 10 | Legacy single tier |
| `secretStore.enabled` / `awsSecret.key` | `false` / `""` | Sync the provider key (property `api-key`) via ESO |

## Example (`infrastructure.yaml`)

```yaml
  - chart: maas-external-model
    name: maas-external-openai
    targetRevision: 0.2.0
    namespace: external-models-openai
    values:
      namespace: external-models-openai
      provider: {name: openai, type: openai, endpoint: api.openai.com, secret: {name: openai-api-key}}
      model:
        name: gpt-4o-mini
        displayName: "GPT-4o mini"
        targetModel: gpt-4o-mini
        path: /v1/chat/completions
      subscriptions:
        free:       {enabled: true, tokenLimit: 100,   tokenWindow: 1m, priority: 10}
        guardrails: {enabled: true, tokenLimit: 20000, tokenWindow: 1m, priority: 15}
      secretStore: {enabled: true}
      awsSecret: {key: rhai/openai/api-key}
```

The AWS SM key must be listed in the Terraform `additional_secrets` so the ESO IRSA role can read it.
