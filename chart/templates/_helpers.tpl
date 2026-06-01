{{/*
Expand the name of the chart.
*/}}
{{- define "mcp-server.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Fully qualified app name, suffixed with the environment so prod and qual
instances never collide (e.g. example-server-prod, example-server-qual).
*/}}
{{- define "mcp-server.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if .Values.fullnameOverride -}}
{{- $name = .Values.fullnameOverride -}}
{{- end -}}
{{- printf "%s-%s" $name .Values.env.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "mcp-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels.
*/}}
{{- define "mcp-server.labels" -}}
helm.sh/chart: {{ include "mcp-server.chart" . }}
{{ include "mcp-server.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: mcp-servers
mcp.platform/environment: {{ .Values.env.name }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "mcp-server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mcp-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Resolve the per-environment vault prefix into a secret reference.
Usage: {{ include "mcp-server.vaultRef" (dict "ref" $value "ctx" $) }}
Replaces the literal token "{{vault}}" with .Values.env.vaultMount, leaving
the resulting <path:...> for AVP to resolve at sync time.
*/}}
{{- define "mcp-server.vaultRef" -}}
{{- $ref := .ref -}}
{{- $mount := .ctx.Values.env.vaultMount -}}
{{- $ref | replace "{{vault}}" $mount -}}
{{- end -}}

{{/*
Full container image reference.
*/}}
{{- define "mcp-server.image" -}}
{{- printf "%s/%s:%s" .Values.image.registry .Values.image.repository (.Values.image.tag | toString) -}}
{{- end -}}
