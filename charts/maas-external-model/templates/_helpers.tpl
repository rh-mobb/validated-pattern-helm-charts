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
  Input: a dict with optional "groups" and "users" lists of names. Groups default to system:authenticated.
  Rendered shape matches the CRDs: groups as [{name: ...}], users as plain strings.
*/ -}}
{{- define "maas-external-model.subjects" -}}
groups:
{{- range (default (list "system:authenticated") .groups) }}
  - name: {{ . }}
{{- end }}
{{- /* users is a plain string list in the MaaS CRDs; omitted when empty because the API server
       drops an empty list, which would otherwise leave the Argo app permanently OutOfSync. */}}
{{- with .users }}
users:
{{- range . }}
  - {{ . | quote }}
{{- end }}
{{- end }}
{{- end }}
