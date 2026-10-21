{{- /*
  _helpers.tpl — shared template helpers for rhai-observability
  Why:       keep common labels consistent across every resource the chart renders
*/ -}}

{{/* Common labels applied to all resources */}}
{{- define "rhai-observability.labels" -}}
app.kubernetes.io/part-of: rhai-observability
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end }}
