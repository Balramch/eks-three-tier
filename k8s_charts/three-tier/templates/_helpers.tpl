{{- define "three-tier.labels" -}}
app.kubernetes.io/name: {{ include "three-tier.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "three-tier.name" -}}
{{ .Chart.Name }}
{{- end -}}

{{- define "three-tier.fullname" -}}
{{ printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end -}}
