#!/usr/bin/env bash
# =============================================================================
# Crée toute la plateforme en une commande :
#   ./bootstrap/bootstrap.sh            # profil local (avec Ollama)
#   ./bootstrap/bootstrap.sh ci <sha>   # profil CI, révision Git précise
#
# Étapes :
#   1. cluster Kubernetes local (kind)
#   2. Argo CD (seule installation « manuelle », via Helm)
#   3. secret Grafana aléatoire (jamais stocké dans Git)
#   4. application racine : à partir de là, Argo CD déploie tout depuis Git
# =============================================================================
set -euo pipefail

PROFILE="${1:-local}"
REVISION="${2:-main}"
CLUSTER="ai-platform"
REPO_URL="${REPO_URL:-https://github.com/Marshall006/k8s-gitops-platform.git}"
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-^10.0.0}"
HERE="$(cd "$(dirname "$0")" && pwd)"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

for cmd in docker kind kubectl helm; do
  command -v "$cmd" >/dev/null || { echo "Outil manquant : $cmd (voir README)"; exit 1; }
done

log "1/4 Cluster kind « $CLUSTER »"
if kind get clusters | grep -qx "$CLUSTER"; then
  echo "Le cluster existe déjà."
else
  kind create cluster --config "$HERE/kind-config.yaml" --wait 120s
fi
kubectl cluster-info --context "kind-$CLUSTER" >/dev/null

log "2/4 Argo CD (chart $ARGOCD_CHART_VERSION)"
helm repo add argo https://argoproj.github.io/argo-helm --force-update >/dev/null
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --version "$ARGOCD_CHART_VERSION" \
  --values "$HERE/argocd-values.yaml" \
  --wait --timeout 10m

log "3/4 Secret administrateur Grafana"
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
if ! kubectl -n monitoring get secret grafana-admin >/dev/null 2>&1; then
  kubectl -n monitoring create secret generic grafana-admin \
    --from-literal=admin-user=admin \
    --from-literal=admin-password="$(openssl rand -base64 18)"
fi

log "4/4 Application racine (profil $PROFILE, révision $REVISION)"
kubectl apply -f - <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: $REPO_URL
    targetRevision: $REVISION
    path: gitops/root
    helm:
      valueFiles:
        - values-$PROFILE.yaml
      parameters:
        - name: repoURL
          value: $REPO_URL
        - name: targetRevision
          value: $REVISION
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
YAML

cat <<INFO

Argo CD déploie maintenant la plateforme depuis Git (5 à 10 minutes).
Suivre l'avancement :   ./bootstrap/wait-for-apps.sh

  Argo CD   http://argocd.localhost       admin / $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
  Grafana   http://grafana.localhost      admin / $(kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d)
  Crédit    http://credit-risk.localhost/docs
  Assistant http://rag.localhost
INFO
