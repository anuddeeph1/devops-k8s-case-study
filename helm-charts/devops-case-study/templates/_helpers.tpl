{{/*
Expand the name of the chart.
*/}}
{{- define "devops-case-study.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "devops-case-study.fullname" -}}
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
{{- define "devops-case-study.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "devops-case-study.labels" -}}
helm.sh/chart: {{ include "devops-case-study.chart" . }}
{{ include "devops-case-study.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "devops-case-study.selectorLabels" -}}
app.kubernetes.io/name: {{ include "devops-case-study.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Web server labels
*/}}
{{- define "devops-case-study.webServer.labels" -}}
{{ include "devops-case-study.labels" . }}
app.kubernetes.io/component: web-server
{{- end }}

{{/*
Web server selector labels
*/}}
{{- define "devops-case-study.webServer.selectorLabels" -}}
{{ include "devops-case-study.selectorLabels" . }}
app.kubernetes.io/component: web-server
app: web-server
tier: frontend
{{- end }}

{{/*
Database labels
*/}}
{{- define "devops-case-study.database.labels" -}}
{{ include "devops-case-study.labels" . }}
app.kubernetes.io/component: database
{{- end }}

{{/*
Database selector labels
*/}}
{{- define "devops-case-study.database.selectorLabels" -}}
{{ include "devops-case-study.selectorLabels" . }}
app.kubernetes.io/component: database
app: mysql
tier: database
{{- end }}

{{/*
Monitoring labels
*/}}
{{- define "devops-case-study.monitoring.labels" -}}
{{ include "devops-case-study.labels" . }}
app.kubernetes.io/component: monitoring
{{- end }}

{{/*
Monitoring selector labels
*/}}
{{- define "devops-case-study.monitoring.selectorLabels" -}}
{{ include "devops-case-study.selectorLabels" . }}
app.kubernetes.io/component: monitoring
app: pod-monitor
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "devops-case-study.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "devops-case-study.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Get namespace name
*/}}
{{- define "devops-case-study.namespace" -}}
{{- default .Release.Namespace .Values.global.namespace }}
{{- end }}
