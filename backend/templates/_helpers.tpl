{{/*
Expand the name of the chart.
*/}}
{{- define "backend.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "backend.fullname" -}}
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
{{- define "backend.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "backend.labels" -}}
helm.sh/chart: {{ include "backend.chart" . }}
{{ include "backend.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "backend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "backend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "backend.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "backend.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}


#################### CUSTOM ######################################################
{{/*
Create service account annotations to include additional info
*/}}
{{- define "backend.k8sServiceAccount.annotations" -}}
{{- if .Values.gcp.k8sServiceAccount.annotations -}}
{{- toYaml .Values.gcp.k8sServiceAccount.annotations  }}
{{- end -}}
iam.gke.io/gcp-service-account: {{ .Values.gcp.iam.serviceAccount.name }}@{{ .Values.gcp.projectId }}.iam.gserviceaccount.com
{{- end }}


{{/*
Create external secrets remote key mapping in order to satisy different envirnoments 
*/}}
{{- define "backend.secretStore.appRoleSecret" -}}
{{- $secretKey := .Values.secretStore.vaultProvider.auth.secret.key -}}
{{- $secretValue := .Values.secretStore.vaultProvider.auth.secret.secretId -}}
{{- if not ($secretValue) -}}
{{- fail "No approle token for value .Values.secretStore.vaultProvider.auth.secret.secretId is not specified!" -}}
{{- end -}}
{{ $secretKey }}: {{ $secretValue | b64enc }}
{{- end }}

{{/*
Create external secrets remote key mapping in order to satisfy different environments 
*/}}
{{- define "backend.externalSecrets.vaultSecretsMapping" -}}
{{- $envType := .Values.environmentType -}}
{{- $vaultPath := .Values.secretStore.vaultProvider.path -}}
{{- $secretDelimiter := .Values.vaultSecrets.secretDelimiter -}}

{{- $groups := .Values.vaultSecrets.groups -}}
{{- range $group := $groups -}}
{{- $secretPrefix := $group.secretPrefix -}}
{{- $vaultFullPath :=  printf "%s/%s/%s" $vaultPath $envType $group.name -}}

{{- range $secret := $group.secrets }}
- secretKey: {{ printf "%s%s%s" $secretPrefix $secretDelimiter .key }}
  remoteRef:
    key: {{ $vaultFullPath }}
    property: {{ .property }}
{{- end }}
{{- end }}
{{- end }} 

{{/*
Create deployment secrets mapping to satisfy different environments
*/}}
{{- define "backend.deployment.secretsMapping" -}}
{{- $envType := .Values.environmentType -}}
{{- $vaultSecrets := .Values.vaultSecrets -}}
{{- $secretTargetName := .Values.externalSecrets.targetName -}}

{{- range $group := $vaultSecrets.groups -}}
{{- $secretPrefix := $group.secretPrefix -}}
{{- $envPrefix := $group.envPrefix -}}

{{- range $secret := $group.secrets }}
- name: {{ printf "%s%s%s" $envPrefix $vaultSecrets.envDelimiter $secret.name }}
  valueFrom:
    secretKeyRef:
      name: {{ $secretTargetName }}
      key: {{ printf "%s%s%s" $secretPrefix $vaultSecrets.secretDelimiter $secret.key }}
{{- end }}
{{- end -}}
{{- end }}


{{/*
Combine private registry credentials
*/}}
{{- define "backend.imagePullSecret" }}
{{- with .Values.imageCredentials }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"email\":\"%s\",\"auth\":\"%s\"}}}" .registry .username .password .email (printf "%s:%s" .username .password | b64enc) | b64enc }}
{{- end }}
{{- end }}

{{/*
Crate the image pull secrets for the deployment
*/}}
{{- define "backend.deployment.imagePullSecrets" -}}
- name: {{ .Values.imageCredentials.registry }}.{{ .Release.Name }}
{{- end -}}

{{/*
Crate the image pull secrets for the deployment
*/}}
{{- define "backend.imagePullSecret.name" -}}
{{ .Values.imageCredentials.registry }}.{{ .Release.Name }}
{{- end -}}

{{/*
Crate pod annotations including additional rolling update checks
*/}}
{{- define "backend.deployment.annotations" -}}
{{- .Values.podAnnotations | toYaml }}
{{- if .Values.deployForceUpdate }}
force.rolling.upage/rand: {{ randAlphaNum 5 | quote }}
{{- end }}
{{- end -}}

