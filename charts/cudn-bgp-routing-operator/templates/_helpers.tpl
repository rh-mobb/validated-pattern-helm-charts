{{- define "cudn-bgp.namespace" -}}
{{- .Values.namespace }}
{{- end -}}

{{- define "cudn-bgp.namePrefix" -}}
{{- .Values.namePrefix }}
{{- end -}}

{{- define "cudn-bgp.labels" -}}
app.kubernetes.io/name: openshift-cudn-bgp-routing
app.kubernetes.io/managed-by: argocd
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "cudn-bgp.selectorLabels" -}}
control-plane: controller-manager
app.kubernetes.io/name: openshift-cudn-bgp-routing
{{- end -}}

{{/*
Full image reference for the manager container.
When buildOperator is enabled, prefer the in-cluster ImageStream tag path so
OpenShift image triggers and local registry pulls stay aligned.
*/}}
{{- define "cudn-bgp.managerImage" -}}
{{- if .Values.buildOperator.enabled -}}
image-registry.openshift-image-registry.svc:5000/{{ include "cudn-bgp.namespace" . }}/{{ .Values.buildOperator.imageStreamName }}:{{ .Values.image.tag }}
{{- else -}}
{{ .Values.image.repository }}:{{ .Values.image.tag }}
{{- end -}}
{{- end -}}
