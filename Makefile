# Raccourcis de la plateforme
.PHONY: up up-ci wait test down passwords lint

up:  ## Crée le cluster et déploie toute la plateforme (profil local)
	./bootstrap/bootstrap.sh local main
	./bootstrap/wait-for-apps.sh

up-ci:  ## Même chose avec le profil CI (sans Ollama)
	./bootstrap/bootstrap.sh ci main
	./bootstrap/wait-for-apps.sh

wait:  ## Attend que toutes les applications Argo CD soient saines
	./bootstrap/wait-for-apps.sh

test:  ## Tests de fumée de bout en bout
	./bootstrap/smoke-test.sh

passwords:  ## Affiche les mots de passe Argo CD et Grafana
	@echo "Argo CD : admin / $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
	@echo "Grafana : admin / $$(kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d)"

lint:  ## Lint des charts
	helm lint charts/ml-service --values apps/credit-risk-api/values.yaml --strict
	helm lint gitops/root --values gitops/root/values-local.yaml --strict

down:  ## Supprime le cluster
	kind delete cluster --name ai-platform
