{{- /*
  _helpers.tpl — shared helpers for maas-external-model
*/ -}}

{{- /*
  maas-external-model.tiers — normalised subscription tiers as YAML (use with fromYaml).
  If .Values.subscriptions is set, it is used as-is (one MaaSSubscription per enabled key).
  Otherwise the legacy single-tier .Values.subscription block becomes tier "free", so charts
  deployed before 0.2.0 render the identical <model>-free MaaSSubscription.
*/ -}}
{{- define "maas-external-model.tiers" -}}
{{- if .Values.subscriptions }}
{{- toYaml .Values.subscriptions }}
{{- else if .Values.subscription.enabled }}
free:
  enabled: true
  tokenLimit: {{ .Values.subscription.tokenLimit }}
  tokenWindow: {{ .Values.subscription.tokenWindow }}
  priority: {{ .Values.subscription.priority }}
{{- end }}
{{- end }}

{{- /*
  maas-external-model.subjects — renders MaaS groups/users subject lists.
  Input: a dict with optional "groups" and "users" lists of names. Defaults to system:authenticated.
*/ -}}
{{- define "maas-external-model.subjects" -}}
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
