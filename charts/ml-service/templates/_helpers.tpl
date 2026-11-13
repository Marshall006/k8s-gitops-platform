{{/* Nom court de l'application */}}
{{- define "ml-service.name" -}}
{{- default .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Étiquettes standard Kubernetes (app.kubernetes.io/*) */}}
{{- define "ml-service.labels" -}}
app.kubernetes.io/name: {{ include "ml-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: ai-platform
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}

{{/* Sélecteur : sous-ensemble STABLE des étiquettes (ne change jamais) */}}
{{- define "ml-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ml-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
