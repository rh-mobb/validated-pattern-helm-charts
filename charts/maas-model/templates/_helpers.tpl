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
  Input: a dict with optional "groups" and "users" lists of names. Groups default to system:authenticated.
  Rendered shape matches the CRDs: groups as [{name: ...}], users as plain strings.
*/ -}}
{{- define "maas-model.subjects" -}}
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
