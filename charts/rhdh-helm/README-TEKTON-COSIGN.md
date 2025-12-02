# Tekton Pipelines & Cosign Integration (Optional)

## Overview

This document describes the **optional** Tekton Pipelines as Code (PaC) and Cosign image signing integration for Red Hat Developer Hub. These features are **NOT required** for the AI Rolling Demo but provide additional CI/CD and supply chain security capabilities.

**Status**: ⚠️ **OPTIONAL** - Only implement if you need CI/CD pipelines or image signing.

---

## Table of Contents

- [What is Tekton Pipelines as Code?](#what-is-tekton-pipelines-as-code)
- [What is Cosign?](#what-is-cosign)
- [Prerequisites](#prerequisites)
- [Tekton Pipelines as Code Setup](#tekton-pipelines-as-code-setup)
- [Cosign Image Signing Setup](#cosign-image-signing-setup)
- [Integration with AI Templates](#integration-with-ai-templates)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

---

## What is Tekton Pipelines as Code?

**Tekton Pipelines as Code (PaC)** allows you to:
- Define CI/CD pipelines in Git repositories (`.tekton/` directory)
- Trigger pipelines automatically via GitHub webhooks
- Build, test, and deploy applications using Tekton tasks
- Integrate with AI Lab Templates for automated model deployment

### Use Cases
- ✅ Automated model training pipelines
- ✅ Continuous deployment of AI applications
- ✅ Container image builds for model servers
- ✅ Integration testing for AI workloads

---

## What is Cosign?

**Cosign** is a tool for signing and verifying container images, providing:
- Cryptographic signatures for container images
- Supply chain security (SLSA compliance)
- Verification of image provenance
- Integration with Tekton for automated signing

### Use Cases
- ✅ Sign AI model container images
- ✅ Verify image integrity before deployment
- ✅ Compliance with security policies
- ✅ Supply chain attestation

---

## Prerequisites

### Required
1. **OpenShift Pipelines Operator** - Already installed via your chart
2. **GitHub App** - Already configured (reuses credentials from `secret_3`)
3. **Cosign CLI** - For local testing (optional)

### Optional
- **Quay.io Account** - For pushing signed images
- **Image Registry** - For storing built images

---

## Tekton Pipelines as Code Setup

### Step 1: Create Pipelines as Code Secret Template

Create a new template for the Tekton PaC secret:

**File**: `templates/pipelines-as-code-secret.yaml`

```yaml
{{- if .Values.pipelinesAsCode.enabled }}
apiVersion: v1
kind: Secret
metadata:
  name: pipelines-as-code-secret
  namespace: openshift-pipelines
type: Opaque
stringData:
  github-application-id: {{ .Values.github.appId | quote }}
  github-private-key: {{ .Values.github.privateKey | quote }}
  webhook.secret: {{ .Values.github.webhookSecret | quote }}
{{- end }}
```

---

### Step 2: Update values.yaml

Add Pipelines as Code configuration:

**File**: `values.yaml`

```yaml
# Tekton Pipelines as Code Configuration
pipelinesAsCode:
  enabled: false  # Set to true to enable
  namespace: openshift-pipelines
```

---

### Step 3: Update Infrastructure File

Enable Pipelines as Code in your infrastructure file:

**File**: `cluster-config/nonprod/np-hub/infrastructure.yaml`

```yaml
- chart: rhdh-helm
  targetRevision: 1.10.1
  namespace: backstage
  values:
    # Enable Pipelines as Code
    pipelinesAsCode:
      enabled: true  # ← Set to true
```

---

### Step 4: Configure Tekton Pipelines as Code

After deploying, configure PaC to use the secret:

```bash
# Create TektonConfig to use the secret
oc apply -f - <<EOF
apiVersion: operator.tekton.dev/v1alpha1
kind: TektonConfig
metadata:
  name: config
spec:
  platforms:
    openshift:
      pipelinesAsCode:
        enable: true
        settings:
          application-name: "Red Hat Developer Hub"
          secret-auto-create: false
          secret-github-app-token-scoped: true
EOF
```

---

### Step 5: Add Pipeline to AI Template

Update your AI Lab templates to include Tekton pipelines:

**Directory Structure**:
```
ai-lab-template/
└── templates/
    └── model-server/
        └── skeleton/
            └── .tekton/
                ├── pipelinerun.yaml
                └── tasks/
                    ├── build-image.yaml
                    ├── deploy-model.yaml
                    └── test-model.yaml
```

**Example PipelineRun**:

```yaml
# .tekton/pipelinerun.yaml
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: model-server-pipeline
  annotations:
    pipelinesascode.tekton.dev/on-event: "[pull_request, push]"
    pipelinesascode.tekton.dev/on-target-branch: "[main]"
spec:
  pipelineSpec:
    tasks:
      - name: build-image
        taskRef:
          name: buildah
        params:
          - name: IMAGE
            value: quay.io/your-org/model-server:latest
      - name: deploy-model
        taskRef:
          name: openshift-client
        runAfter:
          - build-image
```

---

## Cosign Image Signing Setup

### Step 1: Create Cosign Secret Template

Create a template for Cosign signing secrets:

**File**: `templates/cosign-signing-secret.yaml`

```yaml
{{- if .Values.cosign.enabled }}
apiVersion: batch/v1
kind: Job
metadata:
  name: generate-cosign-keys
  namespace: {{ .Values.cosign.namespace | default "openshift-pipelines" }}
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
spec:
  template:
    spec:
      serviceAccountName: pipeline
      containers:
      - name: cosign-keygen
        image: gcr.io/projectsigstore/cosign:v2.2.0
        command:
        - /bin/sh
        - -c
        - |
          # Check if secret already exists
          if kubectl get secret signing-secrets -n {{ .Values.cosign.namespace | default "openshift-pipelines" }} 2>/dev/null; then
            echo "Cosign keys already exist, skipping generation"
            exit 0
          fi
          
          # Generate random password
          COSIGN_PASSWORD=$(openssl rand -base64 30)
          
          # Generate cosign key pair
          COSIGN_PASSWORD=$COSIGN_PASSWORD cosign generate-key-pair k8s://{{ .Values.cosign.namespace | default "openshift-pipelines" }}/signing-secrets
          
          # Mark secret as immutable
          kubectl patch secret signing-secrets -n {{ .Values.cosign.namespace | default "openshift-pipelines" }} \
            --type merge -p '{"immutable": true}'
          
          echo "Cosign signing secret created and marked immutable"
      restartPolicy: OnFailure
  backoffLimit: 3
{{- end }}
```

---

### Step 2: Update values.yaml

Add Cosign configuration:

**File**: `values.yaml`

```yaml
# Cosign Image Signing Configuration
cosign:
  enabled: false  # Set to true to enable
  namespace: openshift-pipelines
```

---

### Step 3: Create Tekton Task for Signing

Create a Tekton task that signs images with Cosign:

**File**: `templates/tekton-sign-image-task.yaml`

```yaml
{{- if .Values.cosign.enabled }}
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: sign-image
  namespace: {{ .Values.cosign.namespace | default "openshift-pipelines" }}
spec:
  params:
    - name: IMAGE
      description: Image to sign
      type: string
  steps:
    - name: sign
      image: gcr.io/projectsigstore/cosign:v2.2.0
      env:
        - name: COSIGN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: signing-secrets
              key: cosign.password
      script: |
        #!/bin/sh
        set -e
        
        echo "Signing image: $(params.IMAGE)"
        
        # Sign the image
        cosign sign --key k8s://{{ .Values.cosign.namespace | default "openshift-pipelines" }}/signing-secrets \
          $(params.IMAGE)
        
        echo "Image signed successfully"
{{- end }}
```

---

### Step 4: Update Pipeline to Include Signing

Add the signing task to your pipeline:

```yaml
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: model-server-pipeline
spec:
  pipelineSpec:
    tasks:
      - name: build-image
        taskRef:
          name: buildah
        params:
          - name: IMAGE
            value: quay.io/your-org/model-server:latest
      
      - name: sign-image
        taskRef:
          name: sign-image
        params:
          - name: IMAGE
            value: quay.io/your-org/model-server:latest
        runAfter:
          - build-image
      
      - name: deploy-model
        taskRef:
          name: openshift-client
        runAfter:
          - sign-image
```

---

## Integration with AI Templates

### Update AI Lab Template to Include Pipeline

**File**: `ai-lab-template/templates/model-server/template.yaml`

Add a step to create the `.tekton` directory:

```yaml
spec:
  steps:
    # ... existing steps ...
    
    - id: create-pipeline
      name: Create Tekton Pipeline
      action: fetch:template
      input:
        url: ./pipeline-skeleton
        targetPath: .tekton
        values:
          name: ${{ parameters.name }}
          image: quay.io/${{ parameters.owner }}/${{ parameters.name }}:latest
```

---

## Testing

### Test Pipelines as Code

1. **Create a Test Repository**:
   ```bash
   # Use Backstage to scaffold a model server
   # Navigate to: https://backstage-backstage.apps.your-cluster.com/create
   # Select: "Model Server, No Application"
   ```

2. **Push to GitHub**:
   ```bash
   cd your-model-server-repo
   git add .tekton/
   git commit -m "Add Tekton pipeline"
   git push
   ```

3. **Verify Webhook Triggered**:
   ```bash
   # Check PipelineRuns
   oc get pipelinerun -n your-namespace
   
   # Check logs
   oc logs -f pipelinerun/model-server-pipeline-run-xxxxx -n your-namespace
   ```

---

### Test Cosign Signing

1. **Build and Sign an Image**:
   ```bash
   # Trigger pipeline (push to GitHub)
   git push
   
   # Wait for pipeline to complete
   oc get pipelinerun -n your-namespace -w
   ```

2. **Verify Image Signature**:
   ```bash
   # Get cosign public key
   oc get secret signing-secrets -n openshift-pipelines \
     -o jsonpath='{.data.cosign\.pub}' | base64 -d > cosign.pub
   
   # Verify image signature
   cosign verify --key cosign.pub quay.io/your-org/model-server:latest
   ```

3. **Check Signature in Registry**:
   ```bash
   # List signatures
   cosign tree quay.io/your-org/model-server:latest
   ```

---

## Troubleshooting

### Issue: Pipelines as Code Not Triggering

**Symptom**: GitHub pushes don't trigger pipelines

**Possible Causes**:
1. GitHub App not installed on repository
2. Webhook not configured
3. Secret not created in `openshift-pipelines` namespace

**Fix**:
```bash
# Check if secret exists
oc get secret pipelines-as-code-secret -n openshift-pipelines

# Check TektonConfig
oc get tektonconfig config -o yaml | grep -A 10 pipelinesAsCode

# Check webhook deliveries in GitHub
# Go to: GitHub > Settings > Webhooks > Recent Deliveries
```

---

### Issue: Cosign Keys Not Generated

**Symptom**: `signing-secrets` secret doesn't exist

**Cause**: PreSync job failed

**Fix**:
```bash
# Check job status
oc get job generate-cosign-keys -n openshift-pipelines

# Check job logs
oc logs job/generate-cosign-keys -n openshift-pipelines

# Manually generate keys
oc create job manual-cosign-gen --from=job/generate-cosign-keys -n openshift-pipelines
```

---

### Issue: Image Signing Fails

**Symptom**: `sign-image` task fails with authentication error

**Possible Causes**:
1. No push access to registry
2. Cosign password not set
3. Secret not mounted

**Fix**:
```bash
# Check if secret exists
oc get secret signing-secrets -n openshift-pipelines

# Check secret keys
oc get secret signing-secrets -n openshift-pipelines -o jsonpath='{.data}' | jq 'keys'

# Verify task has access
oc describe task sign-image -n openshift-pipelines
```

---

### Issue: Pipeline Can't Pull Images

**Symptom**: Pipeline fails with `ImagePullBackOff`

**Cause**: Missing pull secret

**Fix**:
```bash
# Link pull secret to pipeline service account
oc secrets link pipeline redhat-gpte-devhub-pull-secret -n openshift-pipelines

# Verify
oc get sa pipeline -n openshift-pipelines -o yaml | grep imagePullSecrets
```

---

## Configuration Summary

### Minimal Configuration (No Tekton/Cosign)

```yaml
# values.yaml
pipelinesAsCode:
  enabled: false
cosign:
  enabled: false
```

**Result**: No CI/CD pipelines, no image signing

---

### Tekton Only (No Signing)

```yaml
# values.yaml
pipelinesAsCode:
  enabled: true
cosign:
  enabled: false
```

**Result**: GitHub-triggered pipelines, no image signing

---

### Full Configuration (Tekton + Cosign)

```yaml
# values.yaml
pipelinesAsCode:
  enabled: true
  namespace: openshift-pipelines

cosign:
  enabled: true
  namespace: openshift-pipelines
```

**Result**: GitHub-triggered pipelines with automatic image signing

---

## TODO List

### Phase 0: Core Infrastructure (COMPLETED ✅)
- [x] Add `extraVolumes` to values.yaml (dynamic plugins, Lightspeed, RAG)
- [x] Add `extraVolumeMounts` to values.yaml (mount dynamic plugins)
- [x] Add `initContainers` to values.yaml (install plugins, copy RAG data)
- [x] Add `args` to values.yaml (load dynamic plugins config)
- [x] Add Quay pull secret configuration
- [x] Add `NODE_TLS_REJECT_UNAUTHORIZED="0"` environment variable

### Phase 0.5: Recommended Production Enhancements (TODO)
- [ ] Add `readinessProbe` to values.yaml (health checks for pod readiness)
  ```yaml
  readinessProbe:
    failureThreshold: 3
    httpGet:
      path: /healthcheck
      port: 7007
      scheme: HTTP
    initialDelaySeconds: 30
    periodSeconds: 10
    successThreshold: 2
    timeoutSeconds: 2
  ```
- [ ] Add `livenessProbe` to values.yaml (health checks for pod liveness)
  ```yaml
  livenessProbe:
    failureThreshold: 3
    httpGet:
      path: /healthcheck
      port: 7007
      scheme: HTTP
    initialDelaySeconds: 60
    periodSeconds: 10
    successThreshold: 1
    timeoutSeconds: 2
  ```
- [ ] Add `podAnnotations` for dynamic plugin checksum (auto-restart on config changes)
  ```yaml
  podAnnotations:
    checksum/dynamic-plugins: >-
      {{- include "common.tplvalues.render" ( dict "value"
      .Values.global.dynamic "context" $) | sha256sum }}
  ```
- [ ] Add `/developer-hub` proxy endpoint for AI learning paths
  ```yaml
  proxy:
    endpoints:
      "/developer-hub":
        target: https://raw.githubusercontent.com
        pathRewrite:
          "^/api/proxy/developer-hub/learning-paths": "/redhat-developer/rhdh-plugins/refs/heads/main/workspaces/ai-integrations/plugins/ai-experience/src/learning-paths/data.json"
        changeOrigin: true
        secure: false
  ```
- [ ] Add `kubernetes.customResources` for Tekton resources (if using Tekton plugin)
  ```yaml
  kubernetes:
    customResources:
      - apiVersion: v1beta1
        group: tekton.dev
        plural: pipelines
      - apiVersion: v1beta1
        group: tekton.dev
        plural: pipelineruns
      - apiVersion: v1beta1
        group: tekton.dev
        plural: taskruns
      - apiVersion: v1
        group: route.openshift.io
        plural: routes
  ```
- [ ] Consider using `extraEnvVarsSecrets` instead of individual `extraEnvVars` (cleaner approach)
  ```yaml
  extraEnvVarsSecrets:
    - github-app-credentials
    - keycloak-client-secret-backstage
    - backstage-k8s-token
    - llama-stack-secrets  # if Lightspeed enabled
    - lightspeed-mcp-token  # if Lightspeed enabled
  ```

### Phase 1: Tekton Pipelines as Code Setup
- [ ] Create `templates/pipelines-as-code-secret.yaml`
- [ ] Add `pipelinesAsCode` configuration to `values.yaml`
- [ ] Update infrastructure file to enable PaC
- [ ] Create TektonConfig to enable PaC
- [ ] Test webhook triggering from GitHub
- [ ] Verify PipelineRuns execute successfully

### Phase 2: Cosign Image Signing Setup
- [ ] Create `templates/cosign-signing-secret.yaml`
- [ ] Add `cosign` configuration to `values.yaml`
- [ ] Create `templates/tekton-sign-image-task.yaml`
- [ ] Test key generation job
- [ ] Verify signing task works
- [ ] Test signature verification

### Phase 3: AI Template Integration
- [ ] Add `.tekton/` directory to AI Lab templates
- [ ] Create pipeline tasks for model deployment
- [ ] Add signing step to pipelines
- [ ] Update template scaffolding to include pipelines
- [ ] Test end-to-end: scaffold → push → pipeline → sign → deploy

### Phase 4: Documentation & Training
- [ ] Document pipeline structure for AI workloads
- [ ] Create example pipelines for common AI tasks
- [ ] Document Cosign verification process
- [ ] Create troubleshooting guide
- [ ] Train team on pipeline usage

---

## Additional Resources

- [Tekton Pipelines Documentation](https://tekton.dev/docs/)
- [Pipelines as Code Documentation](https://pipelinesascode.com/)
- [Cosign Documentation](https://docs.sigstore.dev/cosign/overview/)
- [OpenShift Pipelines Documentation](https://docs.openshift.com/container-platform/latest/cicd/pipelines/understanding-openshift-pipelines.html)
- [SLSA Framework](https://slsa.dev/)

---

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review Tekton PipelineRun logs
3. Check GitHub webhook deliveries
4. Verify Cosign signatures
5. Contact your platform team

---

**Chart Version**: 1.10.1  
**Last Updated**: December 2024  
**Status**: Optional Feature - Not Required for AI Rolling Demo

