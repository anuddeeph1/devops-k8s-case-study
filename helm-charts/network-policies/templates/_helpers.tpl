{{/*
Expand the name of the chart.
*/}}
{{- define "network-policies.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "network-policies.fullname" -}}
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
{{- define "network-policies.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "network-policies.labels" -}}
helm.sh/chart: {{ include "network-policies.chart" . }}
{{ include "network-policies.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "network-policies.selectorLabels" -}}
app.kubernetes.io/name: {{ include "network-policies.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common annotations for Kyverno policies
*/}}
{{- define "network-policies.annotations" -}}
policies.kyverno.io/category: "Network Security"
policies.kyverno.io/severity: "medium"
policies.kyverno.io/subject: "NetworkPolicy"
policies.kyverno.io/description: "Auto-generated NetworkPolicy via Kyverno"
{{- end }}

{{/*
Generate match conditions for pods based on labels
*/}}
{{- define "network-policies.podMatch" -}}
{{- $podLabel := .podLabel -}}
{{- $namespace := .Values.networkPolicies.targetNamespace -}}
match:
  any:
  - resources:
      kinds:
      - Pod
      namespaces:
      - {{ $namespace }}
      names:
      - "*"
  clusterRoles:
  - "system:controller:*"
  subjects:
  - kind: ServiceAccount
    name: "*"
    namespace: {{ $namespace }}
{{- end }}

{{/*
Generate exclude conditions to prevent policy conflicts
*/}}
{{- define "network-policies.excludeConditions" -}}
exclude:
  any:
  {{- range .Values.excludeNamespaces }}
  - resources:
      namespaces:
      - {{ . }}
  {{- end }}
{{- end }}

{{/*
NetworkPolicy template generation helper
*/}}
{{- define "network-policies.networkPolicyTemplate" -}}
{{- $policyName := .policyName -}}
{{- $spec := .spec -}}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ $policyName }}
  namespace: {{ $.Values.networkPolicies.targetNamespace }}
  labels:
    {{- include "network-policies.labels" $ | nindent 4 }}
    generated-by: kyverno
spec:
{{- toYaml $spec | nindent 2 }}
{{- end }}
