# AI Rolling Demo Integration

## Overview

This document describes the **AI Rolling Demo** components integrated into the Red Hat Developer Hub (Backstage) Helm chart. These components provide a comprehensive AI development experience, including software templates, model catalog integration, and AI-focused UI enhancements.

**Note**: This README covers the AI demo-specific features. For Lightspeed AI Assistant, see [README-LIGHTSPEED.md](./README-LIGHTSPEED.md).

---

## Table of Contents

- [What is AI Rolling Demo?](#what-is-ai-rolling-demo)
- [Components](#components)
- [AI Lab Templates](#ai-lab-templates)
- [AI Experience Plugin](#ai-experience-plugin)
- [Model Catalog Integration](#model-catalog-integration)
- [Configuration](#configuration)
- [Templates](#templates)
- [Deployment](#deployment)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

---

## What is AI Rolling Demo?

The **AI Rolling Demo** is a collection of integrated components that showcase AI/ML capabilities within Red Hat Developer Hub. It provides:

- 🎨 **AI Software Templates** - Pre-built templates for deploying AI applications
- 🏠 **AI Experience Homepage** - Customized homepage with AI-focused navigation
- 📊 **Model Catalog** - Integration with Red Hat OpenShift AI (RHOAI) for model discovery
- 🔧 **Scaffolding Tools** - Automated deployment of AI workloads
- 🎯 **Custom UI Components** - AI-themed branding and navigation

---

## Components

### 1. AI Lab Templates

**Location**: `ai-lab-template/`

Pre-built Backstage software templates for AI/ML workloads:

| Template | Description | Use Case |
|----------|-------------|----------|
| **Model Server** | Deploy LLM inference servers | Serve models via vLLM or llama.cpp |
| **Chatbot Application** | Full-stack chatbot with UI | Build conversational AI apps |
| **RAG Application** | Retrieval-Augmented Generation | Implement context-aware AI |
| **Model Training** | Training pipeline setup | Fine-tune models on OpenShift |

**Key Files**:
- `all.yaml` - Catalog entry point
- `templates/model-server/template.yaml` - Model server template
- `skeleton/` - Template scaffolding code

**Features**:
- ✅ GPU support with tolerations
- ✅ vLLM and llama.cpp support
- ✅ Persistent storage for model caching
- ✅ ArgoCD GitOps integration
- ✅ Tekton CI/CD pipelines

### 2. AI Experience Plugin

**Package**: `oci://quay.io/karthik_jk/ai-experience:1.6.1`

Provides an AI-focused homepage and navigation experience.

**Features**:
- 🏠 **Custom Homepage** - AI-themed landing page
- 📰 **AI News Feed** - Latest AI/ML news and updates
- 🎨 **Custom Icons** - AI-specific iconography
- 🧭 **Dynamic Routes** - AI-focused navigation paths

**Routes**:
- `/` - AI Experience homepage
- `/ai-news` - AI news feed

**Configuration**:
```yaml
plugins:
  - package: oci://quay.io/karthik_jk/ai-experience:1.6.1!red-hat-developer-hub-backstage-plugin-ai-experience
    disabled: false
    pluginConfig:
      dynamicPlugins:
        frontend:
          red-hat-developer-hub.backstage-plugin-ai-experience:
            appIcons:
              - name: aiExperienceIcon
                module: AiExperiencePlugin
                importName: AiExperienceIcon
              - name: aiNewsIcon
                module: AiExperiencePlugin
                importName: AiNewsIcon
            dynamicRoutes:
              - path: /
                importName: AiExperiencePage
              - path: /ai-news
                importName: AiNewsPage
                menuItem:
                  icon: aiNewsIcon
                  text: AI News
```

### 3. Customized Sign-In Page

**Package**: `oci://quay.io/tpetkos/customized-sign-in-page:v0.1.0`

Custom-branded sign-in page with AI theming.

**Features**:
- 🎨 Custom branding
- 🔐 OIDC integration
- 🖼️ Custom background images
- 📱 Responsive design

### 4. Global Header Plugin

**Package**: `red-hat-developer-hub-backstage-plugin-global-header`

Customized navigation header with AI-focused menu items.

**Menu Items**:
- 🏠 Home
- 📚 Catalog
- 🎨 Create (Software Templates)
- 📖 Docs
- 🔧 APIs
- 🔍 Search
- ⚙️ Settings

**Configuration**:
```yaml
pluginConfig:
  dynamicPlugins:
    frontend:
      red-hat-developer-hub.backstage-plugin-global-header:
        dynamicRoutes:
          - importName: GlobalHeader
            menuItems:
              - label: Home
                icon: home
                href: /
              - label: Catalog
                icon: group
                href: /catalog
              # ... more menu items
```

### 5. Model Catalog Integration

**Purpose**: Discover and catalog AI models from Red Hat OpenShift AI (RHOAI).

**Components**:
- **Model Catalog Bridge** - Syncs models from RHOAI to Backstage
- **Catalog Backend Module** - Backstage plugin for model entities
- **Normalizers** - Transform RHOAI model metadata

**Sidecar Containers** (when enabled):
- `location` - Model catalog location service (port 9090)
- `storage-rest` - Storage service for model metadata
- `rhoai-normalizer` - Normalizes RHOAI model data

**RBAC**:
- ServiceAccount: `default` (in backstage namespace)
- Role: `rhdh-rhoai-bridge` - Allows ConfigMap read/write
- Secret: `rhdh-rhoai-bridge-token` - ServiceAccount token

---

## AI Lab Templates

### Template Structure

```
ai-lab-template/
├── all.yaml                          # Catalog entry point
├── org.yaml                          # Organization entities
├── templates/
│   └── model-server/
│       ├── template.yaml             # Template definition
│       └── skeleton/
│           ├── catalog-info.yaml    # Component metadata
│           └── gitops-template/
│               ├── components/
│               │   └── http/
│               │       └── base/
│               │           ├── deployment-model-server.yaml
│               │           ├── service-model-server.yaml
│               │           ├── route-model-server.yaml
│               │           └── pvc-model-cache.yaml
│               └── kustomization.yaml
```

### Model Server Template

**Purpose**: Deploy LLM inference servers (vLLM or llama.cpp)

**Parameters**:
- `name` - Application name
- `owner` - Repository owner
- `modelName` - HuggingFace model name
- `vllmSelected` - Use vLLM (true) or llama.cpp (false)
- `modelServicePort` - Service port (default: 8001)
- `maxModelLength` - Max context length (default: 4096)

**Features**:
- ✅ **GPU Support** - Automatic GPU node selection with tolerations
- ✅ **Model Caching** - PVC for model downloads (reduces startup time)
- ✅ **Security Context** - `fsGroup: 1001` for vLLM write permissions
- ✅ **Init Containers** - Pre-download models (llama.cpp only)
- ✅ **ArgoCD Integration** - GitOps deployment
- ✅ **OpenShift Route** - Automatic external access

**Deployment Flow**:
1. User fills template form in Backstage UI
2. Template scaffolds GitOps repository
3. Creates ArgoCD Application
4. Deploys model server to OpenShift
5. Registers component in Backstage catalog

**Example Deployment**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-model-server
spec:
  template:
    spec:
      securityContext:
        fsGroup: 1001  # For vLLM write access
      containers:
      - name: app-model-service
        image: quay.io/opendatahub/vllm:stable
        args:
          - "--model"
          - "mistralai/Mistral-7B-Instruct-v0.2"
          - "--port"
          - "8001"
          - "--download-dir"
          - "/models-cache"
          - "--max-model-len"
          - "4096"
        resources:
          limits:
            nvidia.com/gpu: '1'
        volumeMounts:
        - name: models-cache
          mountPath: /models-cache
      volumes:
      - name: models-cache
        persistentVolumeClaim:
          claimName: my-model-server
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
```

### Template Customization

**Add Custom Parameters**:
Edit `templates/model-server/template.yaml`:

```yaml
spec:
  parameters:
    - title: Model Configuration
      properties:
        customParam:
          title: Custom Parameter
          type: string
          description: Your custom parameter
```

**Modify Deployment**:
Edit `skeleton/gitops-template/components/http/base/deployment-model-server.yaml`:

```yaml
# Add custom environment variables
env:
  - name: CUSTOM_ENV
    value: ${{ values.customParam }}
```

---

## AI Experience Plugin

### Homepage Customization

The AI Experience plugin provides a customizable homepage.

**Default Layout**:
- Hero section with AI branding
- Quick links to templates
- Recent AI news
- Model catalog highlights

**Customization**:
```yaml
# In values.yaml
redhat-developer-hub:
  global:
    dynamic:
      plugins:
        - package: oci://quay.io/karthik_jk/ai-experience:1.6.1!red-hat-developer-hub-backstage-plugin-ai-experience
          pluginConfig:
            dynamicPlugins:
              frontend:
                red-hat-developer-hub.backstage-plugin-ai-experience:
                  # Custom configuration here
```

### AI News Feed

**Endpoint**: `/ai-news`

**Features**:
- RSS feed aggregation
- AI/ML news sources
- Filterable by topic
- Shareable links

**Configuration**:
```yaml
# In infrastructure.yaml
appConfig:
  proxy:
    endpoints:
      /ai-rssfeed:
        target: https://your-rss-feed-url.com
        changeOrigin: true
```

---

## Model Catalog Integration

### Architecture

```
RHOAI (OpenShift AI)
    ↓
Model Catalog Bridge (Sidecar)
    ↓
Storage REST (Sidecar)
    ↓
RHOAI Normalizer (Sidecar)
    ↓
Backstage Catalog (Model Entities)
```

### Configuration

**Enable Model Catalog**:
```yaml
# In infrastructure.yaml
modelCatalog:
  enabled: true

kubernetes:
  clusterReaderEnabled: true

sidecars:
  enabled: true
```

**RBAC Setup**:
The chart automatically creates:
- ServiceAccount: `default`
- Role: `rhdh-rhoai-bridge`
- RoleBinding: `rhdh-rhoai-bridge-binding`
- Secret: `rhdh-rhoai-bridge-token`

**Sidecar Configuration**:
```yaml
sidecars:
  locationImage: quay.io/redhat-ai-dev/model-catalog-location-service:latest
  storageRestImage: quay.io/redhat-ai-dev/model-catalog-storage-rest:latest
  rhoaiNormalizerImage: quay.io/redhat-ai-dev/model-catalog-rhoai-normalizer:latest
```

### Model Entity Format

Models are registered as Backstage entities:

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: mistral-7b-instruct
  annotations:
    model-catalog/model-id: mistralai/Mistral-7B-Instruct-v0.2
    model-catalog/source: rhoai
spec:
  type: ml-model
  lifecycle: production
  owner: ai-team
```

---

## Configuration

### values.yaml Structure

```yaml
# AI Experience Plugin
redhat-developer-hub:
  global:
    dynamic:
      plugins:
        # AI Experience (Frontend)
        - package: oci://quay.io/karthik_jk/ai-experience:1.6.1!red-hat-developer-hub-backstage-plugin-ai-experience
          disabled: false
        
        # AI Experience (Backend)
        - package: oci://quay.io/karthik_jk/ai-experience:1.6.1!red-hat-developer-hub-backstage-plugin-ai-experience-backend-dynamic
          disabled: false
        
        # Customized Sign-In Page
        - package: oci://quay.io/tpetkos/customized-sign-in-page:v0.1.0!red-hat-developer-hub-backstage-plugin-customized-sign-in-page
          disabled: false
        
        # Global Header
        - package: red-hat-developer-hub-backstage-plugin-global-header
          disabled: false

# Model Catalog Configuration
modelCatalog:
  enabled: false  # Set to true to enable

# Sidecars for Model Catalog
sidecars:
  enabled: false  # Set to true to enable
  locationImage: quay.io/redhat-ai-dev/model-catalog-location-service:latest
  storageRestImage: quay.io/redhat-ai-dev/model-catalog-storage-rest:latest
  rhoaiNormalizerImage: quay.io/redhat-ai-dev/model-catalog-rhoai-normalizer:latest

# Kubernetes Cluster Reader (for Model Catalog)
kubernetes:
  clusterReaderEnabled: false  # Set to true to enable
```

### Infrastructure File Configuration

```yaml
# In np-hub/infrastructure.yaml
- chart: rhdh-helm
  targetRevision: 1.10.0
  namespace: backstage
  values:
    # Enable Model Catalog (optional)
    modelCatalog:
      enabled: true
    
    # Enable Cluster Reader (optional)
    kubernetes:
      clusterReaderEnabled: true
    
    # Enable Sidecars (optional)
    sidecars:
      enabled: true
    
    # Backstage App Config
    redhat-developer-hub:
      upstream:
        backstage:
          appConfig:
            app:
              title: AI Rolling Demo Developer Hub
              baseUrl: https://backstage-backstage.apps.your-cluster.com
            
            # AI Experience CSP Configuration
            backend:
              csp:
                upgrade-insecure-requests: false
                img-src:
                  - "'self'"
                  - "data:"
                  - https://img.freepik.com
                  - https://cdn.dribbble.com
                  - https://upload.wikimedia.org
                  - https://podman-desktop.io
                  - https://argo-cd.readthedocs.io
                  - https://instructlab.ai
                  - https://quay.io
                  - https://news.mit.edu
                script-src:
                  - "'self'"
                  - "'unsafe-eval'"
                  - https://cdn.jsdelivr.net
                connect-src:
                  - "'self'"
                  - https://api.github.com
                  - https://raw.githubusercontent.com
                  - https://github.com
                  - https://*.githubusercontent.com
                  - https://*.apps.your-cluster.com
            
            # AI News Feed Proxy
            proxy:
              endpoints:
                /ai-rssfeed:
                  target: https://your-rss-feed-url.com
                  changeOrigin: true
            
            # Catalog Configuration
            catalog:
              locations:
                - target: https://github.com/your-org/helm-repository/blob/main/charts/rhdh-helm/ai-lab-template/all.yaml
                  type: url
                  rules:
                    - allow: [User, Group, System, Domain, Component, Resource, Location, Template, API]
              
              # Model Catalog Provider (if enabled)
              providers:
                modelCatalog:
                  development:
                    baseUrl: http://localhost:9090
```

---

## Templates

### AI Rolling Demo Templates

| Template | Purpose | Conditional |
|----------|---------|-------------|
| `rolling-demo-sidecars-job.yaml` | PostSync job to inject sidecar containers | `sidecars.enabled` |
| `rolling-demo-rbac.yaml` | Cluster reader binding for model catalog | `kubernetes.clusterReaderEnabled` |
| `model-catalog-rbac.yaml` | RBAC for model catalog bridge (SA, Role, RoleBinding, Secret) | `modelCatalog.enabled` |

### Sidecar Injection Job

**Template**: `templates/rolling-demo-sidecars-job.yaml`

**Purpose**: Injects sidecar containers into the Backstage deployment after sync.

**Hook**: `argocd.argoproj.io/hook: PostSync`

**Containers Injected**:
1. `location` - Port 9090 - Model catalog location service
2. `storage-rest` - Storage service for model metadata
3. `rhoai-normalizer` - Normalizes RHOAI model data
4. `lightspeed-core` - Lightspeed AI service (if Lightspeed enabled)
5. `llama-stack` - LLM inference layer (if Lightspeed enabled)
6. `feedback-harvester` - Feedback collection (if Lightspeed enabled)

**Process**:
1. Wait for Backstage deployment to be ready
2. Check existing containers
3. Build JSON patch for each sidecar
4. Apply patch to deployment
5. Deployment automatically rolls out with new containers

---

## Deployment

### Prerequisites

1. **OpenShift Cluster** - ROSA HCP or standard OpenShift
2. **GPU Nodes** (optional) - For model inference
3. **Storage** - For model caching (PVC)
4. **RHOAI** (optional) - For model catalog integration
5. **GitHub App** - For template scaffolding

### Deployment Steps

#### 1. Configure Catalog Locations

In `infrastructure.yaml`:

```yaml
catalog:
  locations:
    - target: https://github.com/your-org/helm-repository/blob/main/charts/rhdh-helm/ai-lab-template/all.yaml
      type: url
      rules:
        - allow: [User, Group, System, Domain, Component, Resource, Location, Template, API]
```

#### 2. Enable AI Plugins

In `values.yaml`, ensure AI plugins are enabled:

```yaml
plugins:
  - disabled: false  # AI Experience
    package: oci://quay.io/karthik_jk/ai-experience:1.6.1!...
  
  - disabled: false  # Customized Sign-In
    package: oci://quay.io/tpetkos/customized-sign-in-page:v0.1.0!...
  
  - disabled: false  # Global Header
    package: red-hat-developer-hub-backstage-plugin-global-header
```

#### 3. Enable Model Catalog (Optional)

In `infrastructure.yaml`:

```yaml
modelCatalog:
  enabled: true
kubernetes:
  clusterReaderEnabled: true
sidecars:
  enabled: true
```

#### 4. Deploy

```bash
# Commit changes
git add .
git commit -m "Enable AI Rolling Demo features"
git push

# ArgoCD will sync automatically
```

#### 5. Verify

```bash
# Check Backstage pod
oc get pod -n backstage -l app.kubernetes.io/name=backstage

# Check sidecar containers (if enabled)
oc get pod -n backstage -l app.kubernetes.io/name=backstage \
  -o jsonpath='{.items[0].spec.containers[*].name}'

# Access Backstage UI
open https://backstage-backstage.apps.your-cluster.com
```

---

## Testing

### Test AI Lab Templates

1. **Navigate to Create Page**:
   - Go to: `https://backstage-backstage.apps.your-cluster.com/create`

2. **Select Model Server Template**:
   - Choose "Model Server, No Application"

3. **Fill Parameters**:
   - Name: `test-mistral-7b`
   - Owner: `your-github-org`
   - Model Name: `mistralai/Mistral-7B-Instruct-v0.2`
   - vLLM: `true`
   - Port: `8001`
   - Max Length: `4096`

4. **Create**:
   - Click "Create"
   - Wait for scaffolding to complete

5. **Verify Deployment**:
   ```bash
   # Check ArgoCD application
   oc get application -n openshift-gitops test-mistral-7b-app-of-apps
   
   # Check deployment
   oc get deployment -n test-mistral-7b
   
   # Check route
   oc get route -n test-mistral-7b
   
   # Test model endpoint
   curl https://test-mistral-7b-route.apps.your-cluster.com/v1/models
   ```

### Test AI Experience Homepage

1. **Navigate to Homepage**:
   - Go to: `https://backstage-backstage.apps.your-cluster.com/`

2. **Verify AI Branding**:
   - Check for AI-themed hero section
   - Verify quick links to templates
   - Check AI news feed

3. **Test AI News**:
   - Navigate to: `https://backstage-backstage.apps.your-cluster.com/ai-news`
   - Verify news items load
   - Test filtering

### Test Model Catalog

1. **Enable Model Catalog** (if not already):
   ```yaml
   modelCatalog:
     enabled: true
   sidecars:
     enabled: true
   ```

2. **Deploy a Model in RHOAI**:
   - Create a model in OpenShift AI
   - Wait for sync (30 seconds)

3. **Verify in Backstage**:
   - Navigate to: `https://backstage-backstage.apps.your-cluster.com/catalog`
   - Filter by: `type: ml-model`
   - Verify model appears

4. **Check Sidecar Logs**:
   ```bash
   # Location service
   oc logs -n backstage deployment/backstage-backend -c location
   
   # Storage REST
   oc logs -n backstage deployment/backstage-backend -c storage-rest
   
   # RHOAI normalizer
   oc logs -n backstage deployment/backstage-backend -c rhoai-normalizer
   ```

---

## Troubleshooting

### Issue: Templates Not Showing

**Symptom**: AI Lab templates not visible in Create page

**Cause**: Catalog location not loaded

**Fix**:
```bash
# Check catalog locations
oc logs -n backstage deployment/backstage-backend | grep -i "catalog location"

# Verify location URL is accessible
curl -I https://github.com/your-org/helm-repository/blob/main/charts/rhdh-helm/ai-lab-template/all.yaml

# Force catalog refresh
oc rollout restart deployment/backstage-backend -n backstage
```

---

### Issue: Model Server Deployment Fails

**Symptom**: Model server pod in `CrashLoopBackOff`

**Possible Causes**:
1. No GPU nodes available
2. Model download failed
3. Permission denied on PVC

**Fix**:
```bash
# Check pod logs
oc logs -n your-namespace deployment/your-model-server

# Check GPU availability
oc get nodes -l nvidia.com/gpu.present=true

# Check PVC
oc get pvc -n your-namespace

# Check security context
oc get deployment -n your-namespace your-model-server -o yaml | grep -A 5 securityContext
```

---

### Issue: Sidecar Containers Not Injected

**Symptom**: Only `backstage-backend` container in pod

**Cause**: `sidecars.enabled: false` or job failed

**Fix**:
```bash
# Check job status
oc get job -n backstage update-deployment-containers

# Check job logs
oc logs -n backstage job/update-deployment-containers

# Delete job to retry
oc delete job -n backstage update-deployment-containers

# ArgoCD will recreate on next sync
```

---

### Issue: Model Catalog Not Syncing

**Symptom**: Models from RHOAI not appearing in Backstage

**Cause**: Sidecar containers not running or RBAC issue

**Fix**:
```bash
# Check sidecar containers
oc get pod -n backstage -l app.kubernetes.io/name=backstage \
  -o jsonpath='{.items[0].spec.containers[*].name}'

# Check location service logs
oc logs -n backstage deployment/backstage-backend -c location

# Check RBAC
oc get role -n backstage rhdh-rhoai-bridge
oc get rolebinding -n backstage rhdh-rhoai-bridge-binding

# Test ConfigMap access
oc auth can-i get configmaps --as=system:serviceaccount:backstage:default -n backstage
```

---

### Issue: AI Experience Homepage Not Loading

**Symptom**: Homepage shows default Backstage UI

**Cause**: Plugin not loaded or disabled

**Fix**:
```bash
# Check plugin status
oc logs -n backstage deployment/backstage-backend | grep -i "ai-experience"

# Verify plugin is enabled
oc get configmap -n backstage cluster-config-rhdh-helm-values -o yaml | grep -A 5 "ai-experience"

# Restart pod
oc rollout restart deployment/backstage-backend -n backstage
```

---

### Issue: CSP Violations

**Symptom**: Browser console shows CSP errors, images not loading

**Cause**: Missing CSP directives for AI Experience plugin

**Fix**:

Add to `infrastructure.yaml`:
```yaml
backend:
  csp:
    img-src:
      - "'self'"
      - "data:"
      - https://img.freepik.com
      - https://cdn.dribbble.com
      - https://upload.wikimedia.org
      - https://podman-desktop.io
      - https://argo-cd.readthedocs.io
      - https://instructlab.ai
      - https://quay.io
      - https://news.mit.edu
```

---

## Additional Resources

- [AI Lab Templates Repository](https://github.com/redhat-ai-dev/ai-lab-template)
- [AI Experience Plugin](https://github.com/redhat-developer/rhdh-plugins/tree/main/workspaces/ai-integrations/plugins/ai-experience)
- [Model Catalog Bridge](https://github.com/redhat-ai-dev/model-catalog-bridge)
- [RHOAI Documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed)
- [vLLM Documentation](https://docs.vllm.ai/)
- [Backstage Software Templates](https://backstage.io/docs/features/software-templates/)

---

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review template logs in Backstage UI
3. Check pod logs: `oc logs -n backstage deployment/backstage-backend --all-containers`
4. Contact your platform team

---

**Chart Version**: 1.10.0  
**Last Updated**: December 2024  
**Status**: Production Ready


