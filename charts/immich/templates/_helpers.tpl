{{/*
Expand the name of the chart.
*/}}
{{- define "immich.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "immich.fullname" -}}
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
{{- define "immich.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Labels for all resources that are shared between components
*/}}
{{- define "immich.labels" -}}
{{ include "immich.commonLabels" . }}
{{ include "immich.commonSelectorLabels" . }}
{{- end }}

{{/*
Common labels. Not meant to be included directly, but used by the other
helpers.
*/}}
{{- define "immich.commonLabels" -}}
helm.sh/chart: {{ include "immich.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Common selector labels. Not meant to be included directly, but used by the
other helpers.
*/}}
{{- define "immich.commonSelectorLabels" -}}
app.kubernetes.io/name: {{ include "immich.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Server labels to apply to server-specific resources (e.g. Deployment).
*/}}
{{- define "immich.serverLabels" -}}
{{ include "immich.commonLabels" . }}
{{ include "immich.serverSelectorLabels" . }}
{{- end }}

{{/*
Server selector labels to apply anywhere you need a selector for
server-specific resources (e.g. Service or Deployment selectors).
*/}}
{{- define "immich.serverSelectorLabels" -}}
{{ include "immich.commonSelectorLabels" . }}
app.kubernetes.io/component: server
{{- end }}

{{/*
Machine learning labels
*/}}
{{- define "immich.machineLearningLabels" -}}
{{ include "immich.commonLabels" . }}
{{ include "immich.machineLearningSelectorLabels" . }}
{{- end }}

{{/*
Machine learning selector labels
*/}}
{{- define "immich.machineLearningSelectorLabels" -}}
{{ include "immich.commonSelectorLabels" . }}
app.kubernetes.io/component: machine-learning
{{- end }}

{{/*
Workers labels
*/}}
{{- define "immich.workersLabels" -}}
{{ include "immich.commonLabels" . }}
{{ include "immich.workersSelectorLabels" . }}
{{- end }}

{{/*
Workers selector labels
*/}}
{{- define "immich.workersSelectorLabels" -}}
{{ include "immich.commonSelectorLabels" . }}
app.kubernetes.io/component: workers
{{- end }}

{{/*
Return the correct PVC claimName based on whether the user specified an
existing claim or not
*/}}
{{- define "immich.server.persistence.claimName" }}
{{- if .Values.server.persistence.existingClaim }}
{{- .Values.server.persistence.existingClaim }}
{{- else }}
{{- include "immich.fullname" . }}-server
{{- end }}
{{- end }}

{{/*
Return the correct PVC claimName for the upload volume
*/}}
{{- define "immich.server.uploadPersistence.claimName" }}
{{- if .Values.server.uploadPersistence.existingClaim }}
{{- .Values.server.uploadPersistence.existingClaim }}
{{- else }}
{{- include "immich.fullname" . }}-upload
{{- end }}
{{- end }}

{{/*
Return the correct PVC claimName based on whether the user specified an
existing claim or not
*/}}
{{- define "immich.machineLearning.persistence.claimName" }}
{{- if .Values.machineLearning.persistence.existingClaim }}
{{- .Values.machineLearning.persistence.existingClaim }}
{{- else }}
{{- include "immich.fullname" . }}-machine-learning-cache
{{- end }}
{{- end }}

{{/*
Return contents of the config
*/}}
{{- define "immich.serverConfig" }}
immich-config.yaml: |
  {{ tpl (toYaml .Values.server.configuration) . | nindent 2 }}
{{- end }}

{{/*
Return contents of the secret used for environment variables
*/}}
{{- define "immich.server.secretEnv" }}
REDIS_HOSTNAME: {{ (include "valkey.fullname" .Subcharts.valkey ) | b64enc }}
{{- if .Values.postgres.enabled }}
DB_HOSTNAME: {{ printf "%s-%s" (include "immich.fullname" .) "database" | b64enc }}
{{- end }}
{{- range $key, $value := .Values.server.env }}
  {{- if $value }}
{{ $key }}: {{ $value | b64enc }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Check if rclone is truly enabled (enabled flag + all required S3 values set).
Returns "true" or "" (empty string, falsy).
*/}}
{{- define "immich.rclone.enabled" -}}
{{- if and .Values.server.rclone.enabled .Values.server.rclone.s3.endpoint .Values.server.rclone.s3.accessKey .Values.server.rclone.s3.secretKey .Values.server.rclone.s3.bucket -}}
true
{{- end -}}
{{- end -}}

{{/*
Auto-detect the rclone S3 provider from the endpoint URL.
Returns the provider name for rclone (e.g., "AWS", "GCS", "Minio").
Falls back to "Other" if no known provider is detected.
*/}}
{{- define "immich.rclone.s3.provider" -}}
{{- $endpoint := .Values.server.rclone.s3.endpoint -}}
{{- if contains "amazonaws.com" $endpoint -}}
AWS
{{- else if contains "storage.googleapis.com" $endpoint -}}
GCS
{{- else if contains "digitaloceanspaces.com" $endpoint -}}
DigitalOcean
{{- else if contains "blob.core.windows.net" $endpoint -}}
Azure
{{- else if contains "cloud.ovh.net" $endpoint -}}
OVH
{{- else if contains "wasabisys.com" $endpoint -}}
Wasabi
{{- else if contains "backblazeb2.com" $endpoint -}}
B2
{{- else if contains "idrivee2" $endpoint -}}
IDrive
{{- else if contains "r2.cloudflarestorage.com" $endpoint -}}
Cloudflare
{{- else -}}
Other
{{- end -}}
{{- end -}}

{{/*
Auto-detect whether force_path_style should be enabled.
AWS and GCS use virtual-hosted style; most others use path style.
*/}}
{{- define "immich.rclone.s3.forcePathStyle" -}}
{{- $provider := include "immich.rclone.s3.provider" . -}}
{{- if or (eq $provider "AWS") (eq $provider "GCS") -}}
false
{{- else -}}
true
{{- end -}}
{{- end -}}

{{/*
Auto-detect the default region based on provider.
*/}}
{{- define "immich.rclone.s3.region" -}}
{{- if .Values.server.rclone.s3.region -}}
{{- .Values.server.rclone.s3.region -}}
{{- else -}}
{{- $provider := include "immich.rclone.s3.provider" . -}}
{{- if eq $provider "GCS" -}}
auto
{{- else -}}
us-east-1
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return contents of the rclone configmap for checksum calculation
*/}}
{{- define "immich.rcloneConfig" }}
{{- if (include "immich.rclone.enabled" .) }}
provider: {{ include "immich.rclone.s3.provider" . }}
endpoint: {{ .Values.server.rclone.s3.endpoint }}
region: {{ include "immich.rclone.s3.region" . }}
bucket: {{ .Values.server.rclone.s3.bucket }}
pathPrefix: {{ .Values.server.rclone.s3.pathPrefix }}
forcePathStyle: {{ include "immich.rclone.s3.forcePathStyle" . }}
syncInterval: {{ .Values.server.rclone.syncInterval }}
extraFlags: {{ .Values.server.rclone.extraFlags | join "," }}
{{- end }}
{{- end }}
