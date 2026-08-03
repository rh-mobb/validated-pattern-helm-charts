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
