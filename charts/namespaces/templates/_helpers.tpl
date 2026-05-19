{{/*
Expand the name of the chart.
*/}}
{{- define "namespaces.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "namespaces.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "namespaces.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "namespaces.labels" -}}
helm.sh/chart: {{ include "namespaces.chart" . }}
{{ include "namespaces.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "namespaces.selectorLabels" -}}
app.kubernetes.io/name: {{ include "namespaces.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "namespaces.serviceAccountName" -}}
{{- $sa := .Values.serviceAccount }}
{{- if and $sa $sa.create }}
{{- default (include "namespaces.fullname" .) $sa.name }}
{{- else if and $sa $sa.name }}
{{- $sa.name }}
{{- else }}
default
{{- end }}
{{- end }}

{{/*
Helper to extract environment from the values-<ENV>.yaml file
*/}}
{{- define "EnvFromFile" -}}
{{- range $path, $bytes := .Files.Glob "values-*.yaml" }}
{{- $filename := base $path -}}
{{- $split := split "-" $filename -}}
{{- $split1 := index $split 1 -}}
{{- $splitEnv := split "." $split1 -}}
{{- index $splitEnv 0 -}}
{{- end -}}
{{- end -}}
