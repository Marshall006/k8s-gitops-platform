#!/usr/bin/env bash
# Attend que toutes les applications Argo CD soient « Synced » et « Healthy ».
# En cas d'échec, affiche un diagnostic détaillé.
set -euo pipefail
TIMEOUT="${TIMEOUT:-1200}"
start=$(date +%s)

summary() {
  kubectl -n argocd get applications.argoproj.io \
    -o custom-columns='APPLICATION:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status' 2>/dev/null
}

while true; do
  status=$(summary || true)
  total=$(echo "$status" | tail -n +2 | grep -c . || true)
  ready=$(echo "$status" | tail -n +2 | awk '$2=="Synced" && $3=="Healthy"' | wc -l)
  elapsed=$(( $(date +%s) - start ))
  echo "[$elapsed s] $ready/$total applications prêtes"
  if [ "$total" -gt 1 ] && [ "$ready" -eq "$total" ]; then
    echo "$status"
    echo "Toutes les applications sont synchronisées et saines."
    exit 0
  fi
  if [ "$elapsed" -ge "$TIMEOUT" ]; then
    echo "::error::Délai dépassé ($TIMEOUT s)"
    echo "$status"
    for app in $(echo "$status" | tail -n +2 | awk '!($2=="Synced" && $3=="Healthy") {print $1}'); do
      echo "----- $app -----"
      kubectl -n argocd get application "$app" -o jsonpath='{.status.conditions}{"\n"}{.status.operationState.message}{"\n"}' || true
      kubectl -n argocd get application "$app" \
        -o jsonpath='{range .status.resources[?(@.health.status!="Healthy")]}{.kind}/{.namespace}/{.name}: {.health.status} {.health.message}{"\n"}{end}' || true
    done
    kubectl get pods -A | grep -vE "Running|Completed" || true
    kubectl get events -A --sort-by=.lastTimestamp | tail -40 || true
    exit 1
  fi
  sleep 15
done
