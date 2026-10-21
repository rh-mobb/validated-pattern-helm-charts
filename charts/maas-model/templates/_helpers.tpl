{{- /*
  _helpers.tpl — shared helpers for maas-model
*/ -}}

{{- /*
  maas-model.tiers — normalised subscription tiers as YAML (use with fromYaml).
  If .Values.subscriptions is set, it is used as-is (one MaaSSubscription per enabled key).
  Otherwise the legacy .Values.subscription.free / .premium blocks are used, so charts deployed
  before 0.3.0 render the identical <model>-free / <model>-premium MaaSSubscriptions.
*/ -}}
{{- define "maas-model.tiers" -}}
{{- if .Values.subscriptions }}
{{- toYaml .Values.subscriptions }}
{{- else }}
{{- range $tier := list "free" "premium" }}
{{- with (get $.Values.subscription $tier) }}
{{ $tier }}:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{- /*
  maas-model.subjects — renders MaaS groups/users subject lists.
  Input: a dict with optional "groups" and "users" lists of names. Defaults to system:authenticated.
*/ -}}
{{- define "maas-model.subjects" -}}
groups:
{{- range (default (list "system:authenticated") .groups) }}
  - name: {{ . }}
{{- end }}
users:
{{- if .users }}
{{- range .users }}
  - name: {{ . }}
{{- end }}
{{- else }} []
{{- end }}
{{- end }}
