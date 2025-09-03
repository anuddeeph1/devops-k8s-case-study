{{/*
Expand the name of the chart.
*/}}
{{- define "pss-policies.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "pss-policies.fullname" -}}
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
Chart version label
*/}}
{{- define "pss-policies.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "pss-policies.labels" -}}
helm.sh/chart: {{ include "pss-policies.chart" . }}
{{ include "pss-policies.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "pss-policies.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pss-policies.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common annotations
*/}}
{{- define "pss-policies.annotations" -}}
{{- with .Values.commonAnnotations }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Namespace selector for excluding system namespaces
*/}}
{{- define "pss-policies.namespaceSelector" -}}
namespaceSelector:
  matchExpressions:
  {{- range .Values.excludeNamespaces }}
  - key: kubernetes.io/metadata.name
    operator: NotIn
    values:
    - {{ . | quote }}
  {{- end }}
{{- end }}

{{/*
Policy validation failure action - can be overridden per policy
*/}}
{{- define "pss-policies.validationFailureAction" -}}
{{- $policyName := .policyName -}}
{{- if hasKey .Values.policies $policyName -}}
  {{- if hasKey (index .Values.policies $policyName) "validationFailureAction" -}}
    {{- index .Values.policies $policyName "validationFailureAction" }}
  {{- else -}}
    {{- .Values.pss.validationFailureAction }}
  {{- end -}}
{{- else -}}
  {{- .Values.pss.validationFailureAction }}
{{- end -}}
{{- end }}

{{/*
Policy background setting - can be overridden per policy
*/}}
{{- define "pss-policies.background" -}}
{{- $policyName := .policyName -}}
{{- if hasKey .Values.policies $policyName -}}
  {{- if hasKey (index .Values.policies $policyName) "background" -}}
    {{- index .Values.policies $policyName "background" }}
  {{- else -}}
    {{- .Values.pss.background }}
  {{- end -}}
{{- else -}}
  {{- .Values.pss.background }}
{{- end -}}
{{- end }}
