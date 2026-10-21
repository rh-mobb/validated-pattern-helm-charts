{{- /*
  tracing/_setup-script.tpl — shell script shared by the tracing setup Job and the refresh CronJob
  Why:       Three things can't be static manifests:
               1. The MLflow experiment must be created through the MLflow REST API (gives its ID).
               2. OTLP export needs header "Authorization=Bearer <SA token>,X-MLflow-Workspace=<ns>,
                  X-MLflow-Experiment-Id=<id>". The token is minted at runtime (TokenRequest) for the
                  operator-created app SAs.
               3. After a token refresh the app pods must restart (env from Secret is read at start).
             Secrets are written by the script, not rendered by Helm, so Argo never shows drift and the
             tokens never appear in Git or Helm release data.
             Modes (env): FORCE=false skips SAs whose Secret already matches the workspace and
             experiment, so every sync doesn't re-mint tokens. FORCE=true re-mints (CronJob).
             RESTART=true restarts the app Deployments after writing (CronJob).
  Origin:    rhoai-demo-guide setup-mlflow-tracing.sh Phase 1.5, 2.2, 3.2
*/ -}}
{{- define "genai-workspace.tracingSetupScript" -}}
set -euo pipefail
NS="{{ include "genai-workspace.namespace" . }}"
MLFLOW="{{ .Values.tracing.mlflowEndpoint | trimSuffix "/" }}"
EXP_NAME="{{ .Values.tracing.experimentName }}"
DURATION="{{ .Values.tracing.tokenDuration }}"
FORCE="${FORCE:-false}"
RESTART="${RESTART:-false}"
SA_DIR=/var/run/secrets/kubernetes.io/serviceaccount
# MLflow's cert is signed by the OpenShift service CA, injected into every pod's SA mount.
CA="${SA_DIR}/service-ca.crt"
TOKEN="$(cat "${SA_DIR}/token")"

mlflow() {
  curl -sS --cacert "$CA" -H "Authorization: Bearer ${TOKEN}" \
    -H "X-MLflow-Workspace: ${NS}" -H "Content-Type: application/json" "$@"
}
json() { python3 -c "import json,sys; d=json.load(sys.stdin); print($1)" 2>/dev/null || true; }

echo "== 1. Waiting for MLflow at ${MLFLOW}"
ENC_NAME=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$EXP_NAME")
for i in $(seq 1 60); do
  CODE=$(curl -s -o /dev/null -w '%{http_code}' --cacert "$CA" -H "Authorization: Bearer ${TOKEN}" \
    -H "X-MLflow-Workspace: ${NS}" "${MLFLOW}/mlflow/api/2.0/mlflow/experiments/get-by-name?experiment_name=${ENC_NAME}" || echo 000)
  case "$CODE" in 200|404) break ;; esac
  echo "  MLflow not ready (HTTP ${CODE}) ${i}/60"; sleep 10
done

echo "== 2. Ensuring experiment '${EXP_NAME}' in workspace '${NS}'"
EXP_ID=$(mlflow "${MLFLOW}/mlflow/api/2.0/mlflow/experiments/get-by-name?experiment_name=${ENC_NAME}" | json "d['experiment']['experiment_id']")
if [ -z "$EXP_ID" ]; then
  EXP_ID=$(mlflow -X POST "${MLFLOW}/mlflow/api/2.0/mlflow/experiments/create" -d "{\"name\":\"${EXP_NAME}\"}" | json "d['experiment_id']")
fi
if [ -z "$EXP_ID" ]; then
  echo "ERROR: could not get or create experiment. Check: namespace labelled ${NS} as MLflow workspace,"
  echo "       MLflow CR present (rhai-observability), and RoleBinding genai-mlflow-writers."
  exit 1
fi
echo "  experiment id: ${EXP_ID}"

write_header_secret() {
  local sa="$1" secret="$2" deploy="$3"
  local want="X-MLflow-Workspace=${NS},X-MLflow-Experiment-Id=${EXP_ID}"
  if [ "$FORCE" != "true" ]; then
    local cur
    cur=$(oc get secret "$secret" -n "$NS" -o jsonpath='{.data.header}' 2>/dev/null | base64 -d 2>/dev/null || true)
    if [[ "$cur" == *"$want"* ]]; then echo "  ${secret}: up to date, skipping"; return; fi
  fi
  for i in $(seq 1 60); do
    oc get sa "$sa" -n "$NS" >/dev/null 2>&1 && break
    echo "  waiting for ServiceAccount ${sa} (${i}/60)"; sleep 5
  done
  local tok
  tok=$(oc create token "$sa" -n "$NS" --duration="$DURATION")
  # create or replace (not apply: apply would copy the token into a last-applied annotation)
  oc create secret generic "$secret" -n "$NS" \
    --from-literal=header="Authorization=Bearer ${tok},${want}" \
    --dry-run=client -o yaml > /tmp/secret.yaml
  if oc get secret "$secret" -n "$NS" >/dev/null 2>&1; then oc replace -f /tmp/secret.yaml >/dev/null; else oc create -f /tmp/secret.yaml >/dev/null; fi
  rm -f /tmp/secret.yaml
  echo "  ${secret}: written for SA ${sa}"
  if [ "$RESTART" = "true" ] && oc get deployment "$deploy" -n "$NS" >/dev/null 2>&1; then
    oc rollout restart deployment/"$deploy" -n "$NS"
  fi
}

echo "== 3. Writing OTLP auth header Secrets"
{{- if .Values.playground.enabled }}
write_header_secret "{{ .Values.playground.serviceAccount }}" "{{ include "genai-workspace.ogxOtelSecret" . }}" "{{ .Values.playground.name }}"
{{- end }}
{{- if .Values.guardrails.enabled }}
write_header_secret "{{ .Values.guardrails.serviceAccount }}" "{{ include "genai-workspace.ngrOtelSecret" . }}" "nemoguardrails"
{{- end }}
echo "== Done"
{{- end }}

{{- /* Pod spec shared by the setup Job and the refresh CronJob. Input: dict root/force/restart. */ -}}
{{- define "genai-workspace.tracingSetupPod" -}}
{{- $root := .root -}}
restartPolicy: Never
serviceAccountName: genai-tracing-setup
securityContext:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault
containers:
  - name: setup
    image: {{ $root.Values.jobImage }}
    resources:
      requests: {cpu: 100m, memory: 128Mi}
      limits: {cpu: 500m, memory: 256Mi}
    env:
      - name: HOME
        value: /tmp
      - name: FORCE
        value: {{ .force | quote }}
      - name: RESTART
        value: {{ .restart | quote }}
    securityContext:
      {{- include "genai-workspace.jobSecurityContext" $root | nindent 6 }}
    volumeMounts:
      - name: tmp
        mountPath: /tmp
    command:
      - /bin/bash
      - -c
      - |
        {{- include "genai-workspace.tracingSetupScript" $root | nindent 8 }}
volumes:
  - name: tmp
    emptyDir: {}
{{- end }}
