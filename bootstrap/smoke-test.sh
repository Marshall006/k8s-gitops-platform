#!/usr/bin/env bash
# Tests de fumée de bout en bout : l'utilisateur passe par la Gateway, les
# métriques arrivent dans Prometheus, les logs arrivent dans Loki.
set -euo pipefail
BASE="http://localhost"
ok() { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }

retry() {  # retry <description> <commande…>
  local desc="$1"; shift
  for _ in $(seq 1 30); do "$@" >/dev/null 2>&1 && { ok "$desc"; return 0; }; sleep 5; done
  echo "::error::Échec : $desc"; "$@" || true; return 1
}

# 1. Applications joignables via la Gateway (Traefik)
retry "credit-risk.localhost/health" curl -sf -H "Host: credit-risk.localhost" "$BASE/health"
curl -sf -H "Host: credit-risk.localhost" -H "Content-Type: application/json" \
  -X POST "$BASE/predict" -d @"$(dirname "$0")/sample_request.json" | tee /dev/stderr | grep -q probability_default
ok "credit-risk /predict répond"
retry "rag.localhost/health" curl -sf -H "Host: rag.localhost" "$BASE/health"
curl -sf -H "Host: rag.localhost" -H "Content-Type: application/json" -X POST "$BASE/ask" \
  -d '{"question": "How do I set up reordering rules?"}' | grep -q '"sources"'
ok "rag /ask répond avec des sources"
retry "grafana.localhost" curl -sf -H "Host: grafana.localhost" "$BASE/api/health"
retry "argocd.localhost" curl -sf -H "Host: argocd.localhost" "$BASE/healthz"

# Génère un peu de trafic pour les métriques et les logs
for _ in $(seq 1 20); do curl -s -o /dev/null -H "Host: credit-risk.localhost" "$BASE/health"; done

# 2. Prometheus collecte les métriques de l'API
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090 >/dev/null 2>&1 &
PF1=$!
kubectl -n monitoring port-forward svc/loki 3100:3100 >/dev/null 2>&1 &
PF2=$!
trap 'kill $PF1 $PF2 2>/dev/null || true' EXIT
sleep 5

prom_has_target() {
  curl -sf "http://localhost:9090/api/v1/query" \
    --data-urlencode 'query=up{service="credit-risk-api"} == 1' | grep -q '"value"'
}
retry "Prometheus collecte /metrics de credit-risk-api" prom_has_target

prom_has_rules() {
  curl -sf "http://localhost:9090/api/v1/rules" | grep -q "CreditRiskApi\|Creditriskapi"
}
retry "Alertes de credit-risk-api chargées dans Prometheus" prom_has_rules

# 3. Loki reçoit les logs des applications
loki_has_logs() {
  curl -sfG "http://localhost:3100/loki/api/v1/query_range" \
    --data-urlencode 'query={namespace="apps"}' --data-urlencode 'limit=5' | grep -q '"values":\[\['
}
retry "Loki reçoit les logs du namespace apps" loki_has_logs

ok "Plateforme opérationnelle"
