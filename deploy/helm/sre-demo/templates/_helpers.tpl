{{- define "sre-demo.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "sre-demo.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "sre-demo.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "sre-demo.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
app.kubernetes.io/part-of: {{ include "sre-demo.name" . | quote }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end -}}

{{- define "sre-demo.selectorLabels" -}}
app.kubernetes.io/name: {{ include "sre-demo.name" . | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- end -}}

{{- define "sre-demo.backendLabels" -}}
{{ include "sre-demo.selectorLabels" . }}
app.kubernetes.io/component: backend
{{- end -}}

{{- define "sre-demo.frontendLabels" -}}
{{ include "sre-demo.selectorLabels" . }}
app.kubernetes.io/component: frontend
{{- end -}}

{{- define "sre-demo.image" -}}
{{- if .digest -}}
{{- printf "%s@%s" .repository .digest -}}
{{- else -}}
{{- printf "%s:%s" .repository .tag -}}
{{- end -}}
{{- end -}}

{{- define "sre-demo.serviceAccountName" -}}
{{- printf "%s-workload" (include "sre-demo.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
