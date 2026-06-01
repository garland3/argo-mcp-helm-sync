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
The logical environment/namespace segment used inside Vault paths (e.g. the
"qual" in secret/data/mcp/qual/...). Defaults to env.name, so you normally only
set env.name. Override env.namespace if your Vault segment differs.
*/}}
{{- define "mcp-server.namespace" -}}
{{- default .Values.env.name .Values.env.namespace -}}
{{- end -}}

{{/*
Resolve the per-environment tokens inside a secret reference.
Usage: {{ include "mcp-server.vaultRef" (dict "ref" $value "ctx" $) }}

Substitutes the tokens below, leaving the resulting <path:...> for the Argo CD
Vault Plugin to resolve -- either at Argo sync time, OR in CI via the standalone
`argocd-vault-plugin generate` binary (the non-GitOps flow):

  {{namespace}} -> env.namespace (default env.name), e.g. qual | prod
  {{vault}}     -> env.vaultMount (full KV mount+prefix), kept for back-compat
*/}}
{{- define "mcp-server.vaultRef" -}}
{{- $ref := .ref -}}
{{- $ns := include "mcp-server.namespace" .ctx -}}
{{- $mount := .ctx.Values.env.vaultMount -}}
{{- $ref | replace "{{namespace}}" $ns | replace "{{vault}}" $mount -}}
{{- end -}}

{{/*
Full container image reference.
*/}}
{{- define "mcp-server.image" -}}
{{- printf "%s/%s:%s" .Values.image.registry .Values.image.repository (.Values.image.tag | toString) -}}
{{- end -}}

{{/*
ImageStreamTag this server's Deployment follows, e.g. example-server-qual:qual.
The tag defaults to env.name unless imageStream.tag overrides it.
*/}}
{{- define "mcp-server.imageStreamTag" -}}
{{- $tag := default .Values.env.name .Values.imageStream.tag -}}
{{- printf "%s:%s" (include "mcp-server.fullname" .) $tag -}}
{{- end -}}

{{/*
OpenShift Deployment image-trigger annotation. Tells OCP to patch the
container image whenever the tracked ImageStreamTag receives a new image.
*/}}
{{- define "mcp-server.imageTriggers" -}}
{{- $container := include "mcp-server.name" . -}}
{{- $istag := include "mcp-server.imageStreamTag" . -}}
[{"from":{"kind":"ImageStreamTag","name":"{{ $istag }}"},"fieldPath":"spec.template.spec.containers[?(@.name==\"{{ $container }}\")].image"}]
{{- end -}}
