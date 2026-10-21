{{- /*
  _helpers.tpl — shared helpers for genai-workspace
*/ -}}

{{/* Target namespace (required) */}}
{{- define "genai-workspace.namespace" -}}
{{- required "namespace is required" .Values.namespace -}}
{{- end }}

{{/* Common labels. opendatahub.io/dashboard makes resources visible to the RHOAI Dashboard. */}}
{{- define "genai-workspace.labels" -}}
app.kubernetes.io/part-of: genai-workspace
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
opendatahub.io/dashboard: "true"
{{- end }}

{{/* MaaS gateway base URL without trailing slash (required when playground or guardrails is on) */}}
{{- define "genai-workspace.gateway" -}}
{{- required "maas.gateway is required (e.g. https://maas.apps.<cluster-domain>)" .Values.maas.gateway | trimSuffix "/" -}}
{{- end }}

{{/* Secret names written by the tracing setup Job (not rendered by Helm, so no Argo drift) */}}
{{- define "genai-workspace.ogxOtelSecret" -}}otel-mlflow-auth{{- end }}
{{- define "genai-workspace.ngrOtelSecret" -}}nemoguardrails-otel-auth{{- end }}

{{/* Standard restricted container securityContext for Jobs */}}
{{- define "genai-workspace.jobSecurityContext" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop:
    - ALL
{{- end }}
