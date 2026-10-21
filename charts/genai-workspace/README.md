# genai-workspace

A **per-team GenAI workspace** on Red Hat OpenShift AI: everything an app team needs, in its own namespace, to build on the shared Models-as-a-Service (MaaS) models. Deploy **one instance per team namespace** (`name:` override in `infrastructure.yaml`).

Core components (this release):

| Component | What it does for the team |
|---|---|
| **Playground / API** (OGXServer) | GenAI Studio chat UI in the RHOAI Dashboard plus an OpenAI-compatible API. Try models, system prompts, RAG and "Save as Agent". Chat models are MaaS models listed in `playground.models`. |
| **RAG store** (pgvector) | The team's vector database. Uploaded documents are chunked, embedded (granite-embedding-125m, in the OGX pod) and stored here. Relevant chunks are retrieved into each prompt. Isolated per team. |
| **Guardrails** (NemoGuardrails) | Checks every prompt (input rail) and answer (output rail) against the team's plain-English policies, using an LLM judge via MaaS. Catches what model safety training misses: business rules, "educational" phishing, role-play bypasses. |
| **Tracing** (MLflow) | Every Playground call and guardrail decision is exported as a trace (prompt, answer, tokens, latency, block/allow) to the team's MLflow workspace. Only users with RBAC on the namespace can see it. |
| **Verify** | Post-sync smoke test proving the chain works end to end (see [Verification](#verification)). |

```
User ─► Dashboard Playground (OGX) ──► NemoGuardrails input check ──► judge via MaaS (team key)
                 │                                                       │ blocked? stop
                 ├─► pgvector: retrieve document chunks                  │
                 ├─► chat model via MaaS                                 │
                 └─► NemoGuardrails output check ──► judge via MaaS
      every step ──► OTLP traces ──► MLflow (this namespace's workspace)
```

## Boundaries (what is NOT in this chart)

| Concern | Owned by |
|---|---|
| Models, subscriptions (rate limits, metering), access policies | `maas-model` / `maas-external-model` |
| MLflow server, user workload monitoring, MaaS telemetry | `rhai-observability` (one per cluster) |
| Operators and the DataScienceCluster (trustyai, ogx, mlflowoperator) | `rhai-on-openshift-chart` |
| Namespace quota, NetworkPolicy, team RBAC groups | team layer (`applications-ns.yaml` → `namespaces`) |
| The team's application | its own chart (calls this workspace's APIs in production) |

## Who owns what: GitOps vs. the Dashboard UI

The infrastructure Argo apps sync automatically but don't self-heal, never prune, and apply with a three-way merge. So UI changes are never reverted instantly. On the next sync triggered by Git (any values change for this workspace), Argo re-applies the resources that drifted and resets only the fields this chart sets. Fields the chart doesn't set are preserved, and resources the team creates are never touched.

| Team action in the UI | Result | Notes |
|---|---|---|
| Chat, compare models, system prompts | Safe | Nothing written to Kubernetes |
| Upload documents / build vector stores (RAG) | Safe, persistent | Chunks in pgvector; registry and files on the OGX PVC (`playground.storage`) |
| Save as Agent, conversations | Safe, persistent | Stored in OGX's SQL store on the PVC |
| Toggle guardrails on/off in the Playground | Safe | Only decides whether the Dashboard calls NemoGuardrails |
| Edit guardrail policy or model in the UI | **Ignored** | The startup patch drops the Dashboard's inline config; the server config from Git (`guardrails.prompts`, `guardrails.judge.model`) always applies |
| Create workbenches, pipelines, own model deployments, extra ConfigMaps/Secrets | Safe | New resources; Argo doesn't track them |
| Add labels/annotations to the namespace | Safe | The merge keeps fields the chart doesn't set |
| **Change Playground settings / model list in the UI** | **Reverts on next Git sync** | `llama-stack-config` and the OGXServer are Git-owned. Request changes via `playground.models` in cluster-config |
| Delete the Playground in the UI | Recreated on next Git sync, **state lost** | Deleting the OGXServer deletes its operator-owned PVC (registry, files, agents). pgvector chunks remain |

**Model list: Git-owned (default).** Teams request model changes through cluster-config, which keeps the list aligned with MaaS subscriptions and chargeback. A team-managed mode, where the chart creates the Playground config once and then leaves it alone, would need `app-of-apps-infrastructure` to pass through per-entry `ignoreDifferences`. That isn't supported today, so it's a possible future option.

## Prerequisites

1. **rhai-on-openshift-chart** with DSC `trustyai`, `ogx` and `mlflowoperator` set to `Managed`.
2. **rhai-observability** with `mlflow.enabled: true`. Its `mlflow.workspaceLabel` must equal this chart's `mlflowWorkspaceLabel`.
3. **external-secrets-operator** with ClusterSecretStore `aws-secrets-manager`. `rag.pgvector.passwordSource: generator` needs the ESO `Password` generator CRD (`generators.external-secrets.io`).
4. **A MaaS subscription for the judge** with enough headroom. Each check sends roughly 400 tokens and each message triggers 2 checks, so the 100 tokens/min free tier is too small. Add a `guardrails` tier in `maas-external-model`.
5. **The judge's MaaS API key in AWS Secrets Manager** (manual, once per workspace):
   ```bash
   MAAS=https://maas.apps.<cluster-domain>
   KEY=$(curl -sk -X POST "$MAAS/maas-api/v1/api-keys" \
     -H "Authorization: Bearer $(oc whoami -t)" -H "Content-Type: application/json" \
     -d '{"name":"guardrails-demo","subscription":"gpt-4o-mini-guardrails","expiresIn":"8760h"}' \
     | python3 -c "import json,sys; print(json.load(sys.stdin)['key'])")
   aws secretsmanager create-secret --name rhai/guardrails/demo/maas-key \
     --secret-string "{\"api-key\":\"$KEY\"}" --region <region>
   ```
   Add the secret name to Terraform `additional_secrets` so ESO's IRSA role can read it. Whoever creates the key must be in the tier's `owners`. Renew it before it expires.
6. **Model IDs** from `curl -sk $MAAS/v1/models -H "Authorization: Bearer <key>"`, for `playground.models[].id` and `guardrails.judge.model`.

## Resources by sync wave

| Wave | Resource | Area |
|---|---|---|
| -1 | Namespace (dashboard + MLflow workspace labels) | core |
| 0 | ExternalSecret `nemoguardrails-api-key` | guardrails |
| 0 | Password generator + ExternalSecret `genai-pgvector-credentials` | rag |
| 0 | SAs, Roles, RoleBindings (tracing setup, MLflow writers, service fix, verify) | tracing / guardrails / verify |
| 1 | pgvector init ConfigMap, PVC, Service, Deployment | rag |
| 1 | ConfigMap `llama-stack-config` | playground |
| 1 | ConfigMaps `guardrail-placeholder` (config + policies), `nemoguardrails-startup-patch` | guardrails |
| 2 | OGXServer `lsd-genai-playground` | playground |
| 2 | NemoGuardrails `nemoguardrails` | guardrails |
| PostSync 3 | Job `genai-tracing-setup` (+ CronJob `genai-tracing-token-refresh`) | tracing |
| PostSync 4 | Job `genai-ngr-service-fix` | guardrails |
| PostSync 10 | Job `genai-verify` | verify |

With tracing on, the Playground and NemoGuardrails pods wait in `CreateContainerConfigError` until the setup Job writes `otel-mlflow-auth` and `nemoguardrails-otel-auth`. They then start on their own. This is expected on the first sync.

## Values

| Key | Default | Description |
|---|---|---|
| `namespace` | **required** | Workspace namespace |
| `createNamespace` | `true` | `false` when the team layer creates it (then add `opendatahub.io/dashboard: "true"` and the MLflow label there) |
| `mlflowWorkspaceLabel` | `rhai.mobb.io/genai-workspace` | Must match rhai-observability |
| `maas.gateway` | **required** | MaaS base URL without `/v1` |
| `jobImage` | `ose-cli:latest` | Job image (needs `oc` and `python3`) |
| `secretStore.name` / `kind` | `aws-secrets-manager` / `ClusterSecretStore` | ESO store |
| `playground.enabled` | `true` | `false` = headless (guardrails + tracing only, e.g. production) |
| `playground.name` / `serviceAccount` | `lsd-genai-playground` / `lsd-genai-playground-sa` | OGX names |
| `playground.models[]` | **required** if enabled | `{id, displayName}` MaaS models in the dropdown |
| `playground.storage.enabled` / `size` / `mountPath` | `true` / `10Gi` / `/.ogx` | Operator-created PVC for Playground state (registry, files, conversations, agents); `false` = emptyDir, lost on restart |
| `playground.maxTokens` / `tlsVerify` / `resources` | `4096` / `false` / see values | OGX settings |
| `rag.pgvector.image` / `tag` | `rhel9/postgresql-16` / `latest` | Pin `tag` for reproducibility |
| `rag.pgvector.storageSize` / `storageClass` | `5Gi` / `""` | Vector store PVC |
| `rag.pgvector.database` / `user` | `vectordb` / `vectoruser` | DB identity |
| `rag.pgvector.passwordSource` | `generator` | `generator` (ESO, created once) or `awsSecret` (`awsSecretKey`, property `password`) |
| `guardrails.enabled` | `true` | Deploy NemoGuardrails |
| `guardrails.serviceAccount` / `configName` | `nemoguardrails-serviceaccount` / `guardrail-placeholder` | Operator names |
| `guardrails.judge.model` | **required** | MaaS model ID of the judge |
| `guardrails.apiKey.awsSecretKey` / `property` | **required** / `api-key` | AWS SM secret with the judge's MaaS API key |
| `guardrails.prompts` | `""` | Full `prompts.yml` override (default: demo enterprise policies in `files/guardrails/prompts.yml`) |
| `guardrails.fixServicePort` | `true` | Patch Service to 443 → 8443 if needed |
| `tracing.enabled` | `true` | Export traces to MLflow |
| `tracing.experimentName` | `genai-workspace` | Experiment in this workspace |
| `tracing.mlflowEndpoint` | `https://mlflow.redhat-ods-applications.svc:8443` | MLflow endpoint |
| `tracing.tokenDuration` | `8760h` | SA token lifetime in the OTLP headers |
| `tracing.tokenRefresh.enabled` / `schedule` | `true` / monthly | Re-mint tokens and restart app pods |
| `tracing.ogxCertPath` / `ngrCertPath` | SA service-ca / Debian bundle | CA used to trust MLflow |
| `tracing.ogxDisabledInstrumentations` / `ngrDisabledInstrumentations` | see values | Noise filters (keep openai-v2 + fastapi in OGX) |
| `tracing.ogxExcludedUrls` | `v1/health,v1/version,v1/providers` | Paths never traced in OGX (operator status polls would otherwise create an empty trace every few minutes) |
| `verify.enabled` / `startupDelay` / `tracing` / `playground` | `true` / `60` / `true` / `false` | Smoke-test options |
| `verify.safePrompt` / `blockedPrompt` | demo Prompt A / E | Must be allowed / blocked |

## Example (`infrastructure.yaml`)

```yaml
  - chart: genai-workspace
    name: genai-workspace-demo
    targetRevision: 0.1.0
    namespace: demo
    values:
      namespace: demo
      maas:
        gateway: https://maas.apps.rosa.rhai.dfom.p3.openshiftapps.com
      playground:
        models:
          - {id: "<qwen25-3b model id>", displayName: "Qwen 2.5 3B (GPU)"}
          - {id: "<gpt-4o-mini model id>", displayName: "GPT-4o mini"}
      guardrails:
        judge:
          model: "<gpt-4o-mini model id>"
        apiKey:
          awsSecretKey: rhai/guardrails/demo/maas-key
```

## One workspace per team, and the path to production

Each team's values block (models, policies, tracing) is the reviewed, versioned record of its GenAI setup.

| Team / namespace | Use case | Team-specific values |
|---|---|---|
| `support-genai` | Support chatbot with RAG over KB articles | Policies: no refund promises, no competitor comparisons |
| `legal-genai` | Contract summarisation | Strict PII output rails; local model only |
| `devex-genai` | Code assistant | Block secrets and security-bypass instructions |

1. **Dev:** iterate in the Playground, tune `guardrails.prompts`, and inspect traces in MLflow.
2. **Prod:** deploy the same values to `<team>-prod` with `playground.enabled: false`. The team's app calls the guardrails and model APIs, and uses a separate MaaS key on a production tier.
3. **Audit:** production traces land in the prod namespace's MLflow workspace.

## Verification

`genai-verify` (PostSync) checks:

1. Deployments ready; NGR has kube-rbac-proxy; Service on 443:8443; key and OTLP Secrets present.
2. `safePrompt` is allowed and `blockedPrompt` is blocked. This exercises the judge model, MaaS key, subscription and policies.
3. MLflow trace count rises after the checks.
4. Optional (`verify.playground`): one OGX chat completion returns 200.

```bash
oc logs job/genai-verify -n <namespace>
```

### Open items to confirm on a live cluster (0.1.0)

- **Playground → MaaS auth.** The script sets `VLLM_API_TOKEN_1=fake`, so how does the Dashboard authenticate Playground calls to MaaS? Send one Playground message, then check the maas-api, Authorino and Limitador logs and `/maas-api/v1/api-keys`. If OGX needs a real key, a later release adds `playground.maasKey`.
- `playground.storage`: confirm the RHOAI-bundled OGX operator has `spec.workload.storage` (present in upstream ogx-k8s-operator v1beta1, which uses Recreate rollouts with a PVC). Then upload a document, restart the pod, and check the vector store and files are still listed.
- `tracing.ogxCertPath`: confirm the OGX pod mounts the SA token (service-ca.crt present).
- `guardrails.fixServicePort`: confirm whether the current operator already sets 443 → 8443.
- MLflow traces REST path used by verify (`/api/2.0/mlflow/traces`) on the RHOAI MLflow build.
- OGX chat path for `verify.playground` (`/v1/chat/completions`).

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| Pods stuck in `CreateContainerConfigError` | OTLP Secrets not written yet: `oc logs job/genai-tracing-setup -n <ns>`. Check the MLflow CR exists and the namespace has the workspace label |
| Nothing is blocked | Judge model ID wrong, or MaaS key invalid or rate-limited: `oc logs deploy/nemoguardrails -c nemo-guardrails`; check `nemoguardrails-api-key` and the subscription tier |
| "Guardrail check was not applied" in the UI | Service on 80 instead of 443: `oc get svc nemoguardrails -o jsonpath='{.spec.ports[0].port}:{.spec.ports[0].targetPort}'`; keep `fixServicePort: true` |
| No traces at all | OGX: command must be wrapped in `opentelemetry-instrument`. NGR: `PYTHONPATH` must include the startup patch. `oc exec deploy/nemoguardrails -c nemo-guardrails -- python3 -c "from opentelemetry import trace; print(type(trace.get_tracer_provider()).__name__)"` should print `TracerProvider` |
| `401` in MLflow logs | Token expired or the SA lacks `edit` in the namespace. Re-run: `oc create job --from=cronjob/genai-tracing-token-refresh refresh-now -n <ns>` |
| `400 Workspace context is required` | Header Secret missing `X-MLflow-Workspace` / `X-MLflow-Experiment-Id`; re-run the setup Job |
| `SSL CERTIFICATE_VERIFY_FAILED` | Wrong `tracing.ogxCertPath` / `ngrCertPath` |
| Empty Chat tab in MLflow | Needs `span_only` + `gen_ai_latest_experimental` (set by the chart on the OGXServer) |
| Dozens of noisy spans | `tracing.ogxDisabledInstrumentations` trimmed |
| Steady stream of ~3 ms `playground` traces with no LLM call | Operator status polls being traced; check `tracing.ogxExcludedUrls` covers the polled paths (`oc logs deploy/lsd-genai-playground` shows them) |
| Model missing from the Playground dropdown | Not in `playground.models` |
| Vector stores, files or agents disappear after a pod restart | `playground.storage.enabled` false, or the OGXServer was deleted and recreated (new PVC). `oc get pvc <playground.name>-pvc -n <ns>` |
| pgvector auth failures after reinstall | Generator mode made a new password but the PVC keeps the old DB. Delete the PVC or use `passwordSource: awsSecret` |

## Planned modules

Each comes as a minor release with its own `templates/<module>/` folder: `ingestion` (S3 → docling → vector store), `workbench` (pre-wired Jupyter), `mcp` (team MCP servers in OGX), `detectors` (TrustyAI Guardrails Orchestrator: PII, HAP, prompt injection), `evaluation` (LM-Eval / RAG eval into MLflow, prompt registry), and a per-team S3 data connection (needs Terraform).

## Origin

Converted from the imperative `rhoai-demo-guide/scripts/setup-mlflow-tracing.sh` (Phases 0–3). Each template's header names the script step it replaces.
