# Changelog - Version 1.11.0

## 🚀 Major Changes: Dynamic Plugins Infrastructure

This release adds **critical infrastructure** for dynamic plugins, which is required for AI Rolling Demo features like the AI Experience plugin, Customized Sign-In Page, and other OCI-based plugins.

---

## ✅ What Was Added

### 1. **Dynamic Plugins Infrastructure** (CRITICAL)

#### **args** - Load Dynamic Plugins Configuration
```yaml
args:
  - "--config"
  - dynamic-plugins-root/app-config.dynamic-plugins.yaml
```
Tells Backstage to load configuration from the dynamic plugins directory.

---

#### **extraVolumeMounts** - Mount Dynamic Plugins Directory
```yaml
extraVolumeMounts:
  - name: dynamic-plugins-root
    mountPath: /opt/app-root/src/dynamic-plugins-root
```
Mounts the dynamic plugins volume into the Backstage container.

---

#### **extraVolumes** - Storage for Plugins and Lightspeed
```yaml
extraVolumes:
  # Ephemeral storage for dynamic plugin installation (2Gi)
  - name: dynamic-plugins-root
    ephemeral:
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 2Gi
  
  # ConfigMap with plugin configuration
  - name: dynamic-plugins
    configMap:
      defaultMode: 420
      name: "{{ .Release.Name }}-dynamic-plugins"
      optional: true
  
  # NPM configuration for private registries
  - name: dynamic-plugins-npmrc
    secret:
      defaultMode: 420
      optional: true
      secretName: dynamic-plugins-npmrc
  
  # Lightspeed configuration (optional)
  - name: lightspeed-stack
    configMap:
      name: lightspeed-stack
      optional: true
  
  # Shared storage for sidecars (feedback, etc.)
  - name: shared-storage
    emptyDir: {}
  
  # RAG (Retrieval-Augmented Generation) data
  - name: rag-data-volume
    emptyDir: {}
```

**Purpose**:
- `dynamic-plugins-root` - Ephemeral storage for dynamic plugin installation
- `dynamic-plugins` - ConfigMap with plugin configuration
- `dynamic-plugins-npmrc` - NPM configuration for private registries
- `lightspeed-stack` - Lightspeed configuration (only if enabled)
- `shared-storage` - Shared storage for sidecars
- `rag-data-volume` - RAG data for AI features

---

#### **initContainers** - Install Plugins Before Startup
```yaml
initContainers:
  # Install dynamic plugins before Backstage starts
  - name: install-dynamic-plugins
    image: '{{ include "backstage.image" . }}'
    command:
      - ./install-dynamic-plugins.sh
      - /dynamic-plugins-root
    env:
      - name: NPM_CONFIG_USERCONFIG
        value: /opt/app-root/src/.npmrc.dynamic-plugins
    imagePullPolicy: Always
    volumeMounts:
      - mountPath: /dynamic-plugins-root
        name: dynamic-plugins-root
      - mountPath: /opt/app-root/src/dynamic-plugins.yaml
        name: dynamic-plugins
        readOnly: true
        subPath: dynamic-plugins.yaml
      - mountPath: /opt/app-root/src/.npmrc.dynamic-plugins
        name: dynamic-plugins-npmrc
        readOnly: true
        subPath: .npmrc
  
  # Copy RAG data for Lightspeed (optional)
  - name: init-rag-data
    image: 'quay.io/redhat-ai-dev/rag-content:release-1.7-lcs'
    command:
      - "sh"
      - "-c"
      - "echo 'Copying RAG data...'; cp -r /rag/vector_db/rhdh_product_docs /data/ && cp -r /rag/embeddings_model /data/ && echo 'Copy complete.' || echo 'RAG data copy failed or not available'"
    volumeMounts:
      - mountPath: /data
        name: rag-data-volume
```

**Purpose**:
- `install-dynamic-plugins` - Downloads and installs OCI-based plugins before Backstage starts
- `init-rag-data` - Copies RAG data for Lightspeed context-aware responses (optional)

---

## 🎯 Impact

### **Before This Release**
- ❌ Dynamic plugins (AI Experience, Customized Sign-In Page) were **not loading correctly**
- ❌ OCI-based plugins had no installation mechanism
- ❌ Lightspeed RAG data was not available

### **After This Release**
- ✅ Dynamic plugins are **installed automatically** via initContainer
- ✅ OCI-based plugins are **downloaded and extracted** to `/dynamic-plugins-root`
- ✅ Backstage loads plugin configuration from `app-config.dynamic-plugins.yaml`
- ✅ Lightspeed RAG data is available for context-aware responses (if enabled)

---

## 📋 Updated Files

### Chart Files
- `Chart.yaml` - Version bumped to `1.11.0`
- `values.yaml` - Added `args`, `extraVolumeMounts`, `extraVolumes`, `initContainers`

### Configuration Files
- `cluster-config/nonprod/np-hub/infrastructure.yaml` - Updated to `1.11.0`

### Documentation
- `README-TEKTON-COSIGN.md` - Added TODO items for recommended enhancements

---

## 🔄 Migration Guide

### For Existing Deployments

1. **Update the chart version** in your infrastructure file:
   ```yaml
   - chart: rhdh-helm
     targetRevision: 1.11.0
   ```

2. **Sync the ArgoCD application**:
   ```bash
   argocd app sync np-hub-cluster-config-rhdh-helm
   ```

3. **Verify dynamic plugins are loading**:
   ```bash
   # Check initContainer logs
   oc logs -n backstage <backstage-pod> -c install-dynamic-plugins
   
   # Check RAG data initContainer logs (if Lightspeed enabled)
   oc logs -n backstage <backstage-pod> -c init-rag-data
   
   # Check Backstage logs for plugin loading
   oc logs -n backstage <backstage-pod> -c backstage-backend
   ```

4. **Expected behavior**:
   - `install-dynamic-plugins` initContainer should download and extract OCI plugins
   - `init-rag-data` initContainer should copy RAG data (or gracefully fail if not available)
   - Backstage should load plugins from `/dynamic-plugins-root`
   - AI Experience plugin should appear in the UI

---

## 📝 TODO: Recommended Enhancements

The following enhancements are **recommended for production** but not critical:

### Health Probes (Recommended)
```yaml
readinessProbe:
  httpGet:
    path: /healthcheck
    port: 7007
  initialDelaySeconds: 30

livenessProbe:
  httpGet:
    path: /healthcheck
    port: 7007
  initialDelaySeconds: 60
```

### Kubernetes Custom Resources (Optional - Only if using Tekton)
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
```

See `README-TEKTON-COSIGN.md` for the complete TODO list.

---

## 🐛 Known Issues

### Issue 1: RAG Data InitContainer May Fail
**Symptom**: `init-rag-data` initContainer shows error: "RAG data copy failed or not available"

**Impact**: Non-critical - Lightspeed will work without RAG data, but context-aware responses won't be available

**Workaround**: This is expected if you're not using Lightspeed or if the RAG content image is not available. The error is gracefully handled.

---

### Issue 2: Dynamic Plugins ConfigMap Not Found
**Symptom**: `install-dynamic-plugins` initContainer shows warning about missing ConfigMap

**Impact**: Non-critical - The ConfigMap is marked as `optional: true`

**Workaround**: If you need custom plugin configuration, create a ConfigMap named `<release-name>-dynamic-plugins` with a `dynamic-plugins.yaml` key.

---

## 🔍 Troubleshooting

### Dynamic Plugins Not Loading

1. **Check initContainer logs**:
   ```bash
   oc logs -n backstage <backstage-pod> -c install-dynamic-plugins
   ```

2. **Verify volume mount**:
   ```bash
   oc exec -n backstage <backstage-pod> -- ls -la /opt/app-root/src/dynamic-plugins-root
   ```

3. **Check Backstage args**:
   ```bash
   oc get pod -n backstage <backstage-pod> -o jsonpath='{.spec.containers[?(@.name=="backstage-backend")].args}'
   ```
   Should show: `["--config","dynamic-plugins-root/app-config.dynamic-plugins.yaml"]`

4. **Check plugin configuration**:
   ```bash
   oc exec -n backstage <backstage-pod> -- cat /opt/app-root/src/dynamic-plugins-root/app-config.dynamic-plugins.yaml
   ```

---

### RAG Data Not Available

1. **Check initContainer logs**:
   ```bash
   oc logs -n backstage <backstage-pod> -c init-rag-data
   ```

2. **Verify volume mount**:
   ```bash
   oc exec -n backstage <backstage-pod> -- ls -la /data
   ```

3. **If RAG data is not needed**:
   - This is expected and non-critical
   - Lightspeed will work without RAG data

---

## 📚 References

- [Red Hat Developer Hub Dynamic Plugins](https://docs.redhat.com/en/documentation/red_hat_developer_hub)
- [AI Experience Plugin](https://github.com/redhat-developer/rhdh-plugins)
- [Lightspeed Integration](./README-LIGHTSPEED.md)
- [AI Rolling Demo](./README-AI-ROLLING-DEMO.md)

---

**Release Date**: December 2024  
**Chart Version**: 1.11.0  
**Breaking Changes**: None  
**Migration Required**: No (backward compatible)


