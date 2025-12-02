# Lightspeed AI Assistant Integration

## Overview

This document describes the **Lightspeed AI Assistant** integration for Red Hat Developer Hub (Backstage). Lightspeed is an AI-powered virtual assistant that provides contextual help, integrates with your LLM models, and enables advanced AI features within RHDH.

**Status**: ⚠️ **DISABLED BY DEFAULT** - All Lightspeed features are opt-in and require explicit enablement.

---

## Table of Contents

- [What is Lightspeed?](#what-is-lightspeed)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Enabling Lightspeed](#enabling-lightspeed)
- [Disabling Lightspeed](#disabling-lightspeed)
- [Secrets Management](#secrets-management)
- [Templates](#templates)
- [Plugins](#plugins)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

---

## What is Lightspeed?

**Red Hat Developer Hub Lightspeed** is an AI-powered virtual assistant that provides:

- 🤖 **Contextual AI Assistance** - In-depth insights into RHDH capabilities and features
- 🔗 **LLM Integration** - Connects to your existing LLM models (e.g., Mistral, vLLM)
- 🛠️ **Model Context Protocol (MCP)** - Allows AI to interact with Backstage APIs
- 📊 **Model Catalog** - Integration with Red Hat OpenShift AI (RHOAI) for model discovery
- 💬 **Feedback Collection** - Stores user interactions and feedback for continuous improvement

---

## Architecture

When enabled, Lightspeed deploys the following components:

### 1. PostgreSQL Database
- **Purpose**: Stores user feedback and conversation history
- **Namespace**: `lightspeed-postgres` (separate from Backstage)
- **Storage**: 5Gi PVC (configurable)
- **Image**: `registry.redhat.io/rhel9/postgresql-16:latest`

### 2. Sidecar Containers
Injected into the Backstage pod via a PostSync job:

| Container | Purpose |
|-----------|---------|
| `lightspeed-core` | Main Lightspeed service - AI assistant logic |
| `llama-stack` | LLM inference layer - connects to your model endpoint |
| `location` | Model catalog location service - discovers models |
| `storage-rest` | Storage service for model metadata |
| `rhoai-normalizer` | Normalizes RHOAI model data for catalog |
| `feedback-harvester` | Collects user feedback and stores in PostgreSQL |

### 3. Secrets
- `lightspeed-postgres-info` - PostgreSQL connection details (created in 2 namespaces)
- `llama-stack-secrets` - vLLM/LLM model configuration
- `lightspeed-mcp-token` - MCP authentication token

### 4. Dynamic Plugins
Frontend and backend plugins loaded at runtime:
- Lightspeed UI (chat interface)
- Lightspeed backend (AI logic)
- MCP actions backend (API integration)
- MCP tool plugins (catalog, techdocs)
- Model catalog backend (RHOAI integration)

---

## Prerequisites

### Required
1. **LLM Model Endpoint** - A deployed LLM model (e.g., Mistral, Llama, GPT)
   - Must be accessible via HTTP/HTTPS
   - Example: `https://mistral-model.apps.cluster.example.com/v1`

2. **AWS Secrets Manager** - For storing sensitive configuration
   - Secret name: `${cluster_name}-secret-4`
   - Region: Same as your cluster

3. **Storage** - For PostgreSQL PVC
   - At least 5Gi available storage

### Optional
- **Red Hat OpenShift AI (RHOAI)** - For model catalog integration
- **3Scale API Management** - For API gateway and rate limiting (production use)

---

## Configuration

### values.yaml Structure

```yaml
lightspeed:
  enabled: false  # Master switch - set to true to enable
  
  # LLM Model Configuration
  vllmUrl: "https://your-model-endpoint.com/v1"
  vllmApiKey: ""  # Leave empty if no auth required
  validationProvider: "vllm"  # Options: vllm, ollama, openai
  validationModelName: "mistralai/Mistral-Small-Instruct-2409"
  
  # MCP Authentication
  mcpToken: "your-secure-mcp-token"
  
  # PostgreSQL Configuration
  postgres:
    enabled: false  # Set to true to deploy PostgreSQL
    namespace: lightspeed-postgres
    image: registry.redhat.io/rhel9/postgresql-16:latest
    storageSize: 5Gi
    user: lightspeed
    password: "secure-password-here"
    dbName: lightspeed

# Model Catalog (RHOAI Integration)
modelCatalog:
  enabled: false  # Set to true to enable model catalog

# Kubernetes Cluster Reader
kubernetes:
  clusterReaderEnabled: false  # Set to true for model catalog

# Sidecar Containers
sidecars:
  enabled: false  # Set to true to inject sidecars
  serviceAccount: default
  image: quay.io/redhat-ai-dev/utils:latest
  locationImage: quay.io/redhat-ai-dev/model-catalog-location-service:latest
  storageRestImage: quay.io/redhat-ai-dev/model-catalog-storage-rest:latest
  rhoaiNormalizerImage: quay.io/redhat-ai-dev/model-catalog-rhoai-normalizer:latest
  llamaStackImage: quay.io/redhat-ai-dev/llama-stack:0.1.0
  lightspeedCoreImage: quay.io/lightspeed-core/lightspeed-stack:dev-20251021-ee9f08f
  feedbackHarvesterImage: quay.io/redhat-ai-dev/feedback-harvester:v0.1.0
```

---

## Enabling Lightspeed

### Step 1: Create AWS Secrets Manager Secret

Create a secret named `${cluster_name}-secret-4` with the following JSON:

```json
{
  "vllmUrl": "https://your-model-endpoint.com/v1",
  "vllmApiKey": "",
  "validationProvider": "vllm",
  "validationModelName": "your-model-name",
  "lightspeedPostgresPassword": "generate-with-openssl-rand-base64-32",
  "lightspeedPostgresUser": "lightspeed",
  "lightspeedPostgresDb": "lightspeed",
  "mcpToken": "generate-with-openssl-rand-base64-32"
}
```

**Generate secure tokens**:
```bash
openssl rand -base64 32  # For lightspeedPostgresPassword
openssl rand -base64 32  # For mcpToken
```

### Step 2: Update Infrastructure File

In your infrastructure YAML (e.g., `np-hub/infrastructure.yaml`):

```yaml
- chart: rhdh-helm
  targetRevision: 1.10.0
  namespace: backstage
  values:
    # ... existing config ...
    
    # Enable Lightspeed
    lightspeed:
      enabled: true  # ← Enable Lightspeed
      vllmUrl: "<path:np-hub-secret-4#vllmUrl>"
      vllmApiKey: "<path:np-hub-secret-4#vllmApiKey>"
      validationProvider: "<path:np-hub-secret-4#validationProvider>"
      validationModelName: "<path:np-hub-secret-4#validationModelName>"
      mcpToken: "<path:np-hub-secret-4#mcpToken>"
      postgres:
        enabled: true  # ← Enable PostgreSQL
        user: "<path:np-hub-secret-4#lightspeedPostgresUser>"
        password: "<path:np-hub-secret-4#lightspeedPostgresPassword>"
        dbName: "<path:np-hub-secret-4#lightspeedPostgresDb>"
    
    # Enable Model Catalog (optional)
    modelCatalog:
      enabled: true
    
    # Enable Cluster Reader (optional, for model catalog)
    kubernetes:
      clusterReaderEnabled: true
    
    # Enable Sidecar Containers
    sidecars:
      enabled: true
```

### Step 3: Enable Plugins

In `values.yaml`, change `disabled: true` to `disabled: false` for:

```yaml
plugins:
  # Lightspeed Frontend
  - disabled: false  # ← Change to false
    package: oci://ghcr.io/.../red-hat-developer-hub-backstage-plugin-lightspeed:...
  
  # Lightspeed Backend
  - disabled: false  # ← Change to false
    package: oci://ghcr.io/.../red-hat-developer-hub-backstage-plugin-lightspeed-backend:...
  
  # MCP Actions Backend
  - disabled: false  # ← Change to false
    package: oci://ghcr.io/.../backstage-plugin-mcp-actions-backend:...
  
  # MCP Tool Plugins
  - disabled: false  # ← Change to false
    package: oci://ghcr.io/.../red-hat-developer-hub-backstage-plugin-software-catalog-mcp-tool:...
  
  - disabled: false  # ← Change to false
    package: oci://ghcr.io/.../red-hat-developer-hub-backstage-plugin-techdocs-mcp-tool:...
  
  # Model Catalog (if using RHOAI)
  - disabled: false  # ← Change to false
    package: oci://ghcr.io/.../red-hat-developer-hub-backstage-plugin-catalog-backend-module-model-catalog:...
```

### Step 4: Deploy

```bash
# Bump chart version in Chart.yaml
# Update targetRevision in infrastructure file
# Commit and push changes
git add .
git commit -m "Enable Lightspeed AI Assistant"
git push

# ArgoCD will sync automatically
```

---

## Disabling Lightspeed

### Current State (Default)
Lightspeed is **DISABLED BY DEFAULT**. All configuration is in place but inactive.

### To Explicitly Disable

1. **In infrastructure file**, set:
   ```yaml
   lightspeed:
     enabled: false
     postgres:
       enabled: false
   modelCatalog:
     enabled: false
   kubernetes:
     clusterReaderEnabled: false
   sidecars:
     enabled: false
   ```

2. **In values.yaml**, set plugins to `disabled: true`

3. **Impact**: Zero - no resources created, no overhead

---

## Secrets Management

### Secrets Created (when enabled)

#### 1. `lightspeed-postgres-info` (2 instances)
Created in both `lightspeed-postgres` and `backstage` namespaces.

**Template**: `templates/lightspeed-postgres-info-secret.yaml`

**Keys**:
- `namespace` - PostgreSQL namespace
- `user` - PostgreSQL username
- `password` - PostgreSQL password
- `db-name` - PostgreSQL database name

#### 2. `llama-stack-secrets`
Created in `backstage` namespace.

**Template**: `templates/llama-stack-secrets.yaml`

**Keys**:
- `VLLM_URL` - LLM model endpoint
- `VLLM_API_KEY` - API key (if required)
- `VALIDATION_PROVIDER` - Provider type (vllm, ollama, openai)
- `VALIDATION_MODEL_NAME` - Model identifier

#### 3. `lightspeed-mcp-token`
Created in `backstage` namespace.

**Template**: `templates/lightspeed-mcp-token-secret.yaml`

**Keys**:
- `mcpToken` - MCP authentication token

### Secret Flow

```
Terraform (3.secrets.tf)
    ↓
AWS Secrets Manager (secret_4)
    ↓
ArgoCD Vault Plugin (reads from AWS)
    ↓
Infrastructure YAML (injects values)
    ↓
Helm Chart (creates K8s secrets)
    ↓
Backstage Pod (mounts secrets as env vars)
```

---

## Templates

### Core Templates

| Template | Purpose | Conditional |
|----------|---------|-------------|
| `lightspeed-postgres.yaml` | PostgreSQL deployment, service, PVC, init job | `lightspeed.postgres.enabled` |
| `lightspeed-postgres-info-secret.yaml` | PostgreSQL connection secrets (2 namespaces) | `lightspeed.enabled` |
| `lightspeed-stack-config.yaml` | Lightspeed configuration ConfigMap | `lightspeed.enabled` |
| `lightspeed-mcp-token-secret.yaml` | MCP authentication token secret | `lightspeed.enabled` |
| `llama-stack-secrets.yaml` | LLM model configuration secret | `lightspeed.enabled` |
| `rolling-demo-sidecars-job.yaml` | PostSync job to inject sidecar containers | `sidecars.enabled` |
| `rolling-demo-rbac.yaml` | Cluster reader binding for model catalog | `kubernetes.clusterReaderEnabled` |
| `model-catalog-rbac.yaml` | RBAC for model catalog bridge | `modelCatalog.enabled` |

### Template Conditions

All Lightspeed templates use conditional rendering:

```yaml
{{- if .Values.lightspeed.enabled }}
# Template content here
{{- end }}
```

**Result**: When `lightspeed.enabled: false`, templates produce **zero resources**.

---

## Plugins

### Plugin List

| Plugin | Type | Purpose | Default |
|--------|------|---------|---------|
| `red-hat-developer-hub-backstage-plugin-lightspeed` | Frontend | Lightspeed UI (chat interface) | `disabled: true` |
| `red-hat-developer-hub-backstage-plugin-lightspeed-backend` | Backend | Lightspeed AI logic | `disabled: true` |
| `backstage-plugin-mcp-actions-backend` | Backend | MCP API integration | `disabled: true` |
| `red-hat-developer-hub-backstage-plugin-software-catalog-mcp-tool` | Backend | Software catalog MCP tool | `disabled: true` |
| `red-hat-developer-hub-backstage-plugin-techdocs-mcp-tool` | Backend | TechDocs MCP tool | `disabled: true` |
| `red-hat-developer-hub-backstage-plugin-catalog-backend-module-model-catalog` | Backend | RHOAI model catalog | `disabled: true` |
| `red-hat-developer-hub-backstage-plugin-catalog-techdoc-url-reader-backend` | Backend | TechDoc URL reader | `disabled: true` |

### Plugin Configuration

Plugins are configured in `values.yaml` under `redhat-developer-hub.global.dynamic.plugins`.

**Key Configuration**:
```yaml
pluginConfig:
  dynamicPlugins:
    frontend:
      red-hat-developer-hub.backstage-plugin-lightspeed:
        dynamicRoutes:
          - path: /lightspeed
            importName: LightspeedPage
            module: LightspeedPlugin
            menuItem:
              icon: LightspeedIcon
              text: Lightspeed
```

---

## Testing

### Verify Lightspeed is Disabled (Default State)

```bash
# Check no Lightspeed secrets exist
oc get secrets -n backstage | grep -E "lightspeed|llama-stack|mcp-token"
# Expected: No output

# Check no PostgreSQL deployed
oc get all -n lightspeed-postgres
# Expected: "No resources found"

# Check Backstage pod has only 1 container
oc get pod -n backstage -l app.kubernetes.io/name=backstage \
  -o jsonpath='{.items[0].spec.containers[*].name}'
# Expected: backstage-backend
```

### Verify Lightspeed is Enabled

```bash
# 1. Check secrets exist
oc get secrets -n backstage | grep -E "lightspeed|llama-stack|mcp-token"
# Expected: 3 secrets

# 2. Check PostgreSQL is running
oc get pod -n lightspeed-postgres
# Expected: 1 pod running

# 3. Check sidecar containers injected
oc get pod -n backstage -l app.kubernetes.io/name=backstage \
  -o jsonpath='{.items[0].spec.containers[*].name}'
# Expected: backstage-backend location storage-rest rhoai-normalizer lightspeed-core llama-stack feedback-harvester

# 4. Check Lightspeed UI is accessible
curl -I https://backstage-backstage.apps.your-cluster.com/lightspeed
# Expected: 200 OK

# 5. Check MCP authentication
oc logs -n backstage deployment/backstage-backend -c lightspeed-core | grep -i mcp
# Expected: MCP server initialized

# 6. Check model connection
oc logs -n backstage deployment/backstage-backend -c llama-stack | grep -i "model loaded"
# Expected: Model loaded successfully
```

### Test Lightspeed Functionality

1. **Access Lightspeed UI**:
   - Navigate to: `https://backstage-backstage.apps.your-cluster.com/lightspeed`
   - You should see the Lightspeed chat interface

2. **Test AI Response**:
   - Ask: "What is Red Hat Developer Hub?"
   - Verify you get a contextual AI response

3. **Test MCP Integration**:
   - Ask: "List all components in the catalog"
   - Verify the AI can query the Backstage catalog

4. **Check Feedback Storage**:
   ```bash
   oc exec -n lightspeed-postgres deployment/lightspeed-postgres -- \
     psql -U lightspeed -d lightspeed -c "SELECT COUNT(*) FROM feedback;"
   ```

---

## Troubleshooting

### Issue: Secrets Not Created

**Symptom**: `oc get secrets -n backstage` shows no Lightspeed secrets

**Cause**: `lightspeed.enabled: false` in values

**Fix**:
```yaml
# In infrastructure file
lightspeed:
  enabled: true  # Must be true
```

---

### Issue: PostgreSQL Pod Not Starting

**Symptom**: PostgreSQL pod in `CrashLoopBackOff` or `Pending`

**Possible Causes**:
1. Namespace doesn't exist
2. PVC not bound
3. Image pull error

**Fix**:
```bash
# Check namespace
oc get namespace lightspeed-postgres

# Check PVC
oc get pvc -n lightspeed-postgres
# If not bound, check storage class

# Check pod logs
oc logs -n lightspeed-postgres deployment/lightspeed-postgres

# Check events
oc get events -n lightspeed-postgres --sort-by='.lastTimestamp'
```

---

### Issue: Sidecar Containers Not Injected

**Symptom**: Backstage pod has only 1 container

**Cause**: `sidecars.enabled: false` or job failed

**Fix**:
```bash
# Check if sidecars are enabled
oc get configmap -n backstage cluster-config-rhdh-helm-values -o yaml | grep "enabled:"

# Check job status
oc get job -n backstage update-deployment-containers

# Check job logs
oc logs -n backstage job/update-deployment-containers

# If job failed, delete and let ArgoCD recreate
oc delete job -n backstage update-deployment-containers
```

---

### Issue: Lightspeed UI Not Showing

**Symptom**: `/lightspeed` route returns 404

**Possible Causes**:
1. Frontend plugin disabled
2. Plugin not loaded
3. Route not configured

**Fix**:
```bash
# Check plugin status
oc logs -n backstage deployment/backstage-backend | grep -i lightspeed

# Check if plugin is disabled
oc get configmap -n backstage cluster-config-rhdh-helm-values -o yaml | grep -A 5 "lightspeed"

# Restart Backstage pod
oc rollout restart deployment/backstage-backend -n backstage
```

---

### Issue: MCP Authentication Failing

**Symptom**: Logs show "MCP authentication failed" or "Unauthorized"

**Cause**: MCP_TOKEN mismatch between secret and backend config

**Fix**:
```bash
# Check MCP token in secret
oc get secret -n backstage lightspeed-mcp-token -o jsonpath='{.data.mcpToken}' | base64 -d

# Check MCP token in environment
oc exec -n backstage deployment/backstage-backend -c backstage-backend -- env | grep MCP_TOKEN

# Verify backend.auth.externalAccess config
oc get configmap -n backstage cluster-config-rhdh-helm-developer-hub-app-config -o yaml | grep -A 5 "mcp-clients"

# If mismatch, update infrastructure file and resync
```

---

### Issue: Model Connection Failed

**Symptom**: Logs show "Failed to connect to model endpoint"

**Possible Causes**:
1. Model endpoint unreachable
2. Incorrect URL
3. API key required but not provided

**Fix**:
```bash
# Check llama-stack logs
oc logs -n backstage deployment/backstage-backend -c llama-stack

# Test model endpoint from pod
oc exec -n backstage deployment/backstage-backend -c llama-stack -- \
  curl -v https://your-model-endpoint.com/v1/health

# Check VLLM_URL in secret
oc get secret -n backstage llama-stack-secrets -o jsonpath='{.data.VLLM_URL}' | base64 -d

# If incorrect, update infrastructure file and resync
```

---

### Issue: Feedback Not Saving

**Symptom**: User feedback not appearing in PostgreSQL

**Cause**: Feedback harvester not running or PostgreSQL connection issue

**Fix**:
```bash
# Check feedback-harvester logs
oc logs -n backstage deployment/backstage-backend -c feedback-harvester

# Test PostgreSQL connection
oc exec -n lightspeed-postgres deployment/lightspeed-postgres -- \
  psql -U lightspeed -d lightspeed -c "SELECT 1;"

# Check feedback table exists
oc exec -n lightspeed-postgres deployment/lightspeed-postgres -- \
  psql -U lightspeed -d lightspeed -c "\dt"

# If table missing, check init job
oc logs -n lightspeed-postgres job/lightspeed-postgres-init
```

---

## Additional Resources

- [Red Hat Developer Hub Documentation](https://docs.redhat.com/en/documentation/red_hat_developer_hub)
- [Lightspeed Plugin Repository](https://github.com/redhat-developer/rhdh-plugins/tree/main/workspaces/lightspeed)
- [Model Context Protocol (MCP)](https://github.com/redhat-developer/rhdh-plugins/tree/main/workspaces/mcp-integrations)
- [Model Catalog Bridge](https://github.com/redhat-ai-dev/model-catalog-bridge)
- [RHOAI Documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed)

---

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review pod logs: `oc logs -n backstage deployment/backstage-backend --all-containers`
3. Check ArgoCD application status
4. Contact your platform team

---

**Chart Version**: 1.10.0  
**Last Updated**: December 2024  
**Status**: Production Ready (when enabled)


