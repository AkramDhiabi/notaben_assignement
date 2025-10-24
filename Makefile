.PHONY: help init plan apply destroy outputs status argocd-ui deploy-app check-app app-ui clean clean-all local-test local-clean local-status local-argocd-password configure-kubectl argocd-password

AWS_REGION := eu-central-1
CLUSTER_NAME := notaben-eks-cluster
ARGOCD_NAMESPACE := argocd
APP_NAMESPACE := nb-challenge

##@ General

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Infrastructure

init: ## Initialize Terraform
	cd terraform && terraform init

plan: ## Show Terraform execution plan
	cd terraform && terraform plan

apply: ## Deploy infrastructure (EKS + ArgoCD)
	@echo "This will take ~15 minutes"
	cd terraform && terraform apply

destroy: ## Destroy all infrastructure
	@echo "WARNING: This will destroy all resources!"
	@echo "Press Ctrl+C to cancel or wait 5 seconds to continue..."
	@sleep 5
	cd terraform && terraform destroy

outputs: ## Show Terraform outputs
	cd terraform && terraform output

##@ Cluster Access

configure-kubectl: ## Configure kubectl for EKS cluster
	aws eks update-kubeconfig --region $(AWS_REGION) --name $(CLUSTER_NAME)

status: configure-kubectl ## Show cluster status (nodes, pods, services)
	@kubectl get nodes
	@kubectl get pods -A
	@kubectl get svc -A

##@ ArgoCD

argocd-password: configure-kubectl ## Get ArgoCD admin password
	@kubectl get secret argocd-initial-admin-secret -n $(ARGOCD_NAMESPACE) -o jsonpath='{.data.password}' | base64 -d
	@echo ""

argocd-ui: configure-kubectl ## Access ArgoCD UI at https://localhost:8080
	@echo "ArgoCD UI: https://localhost:8080"
	@echo "Username: admin"
	@echo "Password: Run 'make argocd-password'"
	kubectl port-forward svc/argocd-server -n $(ARGOCD_NAMESPACE) 8080:443

##@ Application

deploy-app: configure-kubectl ## Deploy application via ArgoCD
	@echo "Ensure Git repo URL is updated in argocd/application.yaml"
	kubectl apply -f argocd/application.yaml
	@echo "Check status: make check-app"

check-app: configure-kubectl ## Check application status
	@kubectl get application simple-app -n $(ARGOCD_NAMESPACE)
	@kubectl get pods -n $(APP_NAMESPACE) -l app=simple-app
	@kubectl get svc -n $(APP_NAMESPACE) simple-app

app-ui: configure-kubectl ## Access application at http://localhost:8081
	@echo "Application: http://localhost:8081"
	kubectl port-forward svc/simple-app -n $(APP_NAMESPACE) 8081:80

##@ Cleanup

clean: configure-kubectl ## Remove application only
	kubectl delete -f argocd/application.yaml --ignore-not-found=true

clean-all: clean destroy ## Remove everything (application + infrastructure)

##@ Local Testing (Kind)

local-test: ## Setup local Kind cluster with ArgoCD and deploy app
	@./local-test/setup.sh

local-clean: ## Delete local Kind cluster
	@./local-test/cleanup.sh

local-status: ## Check local Kind cluster status
	@kubectl --context kind-notaben-local get nodes
	@kubectl --context kind-notaben-local get pods -A
	@kubectl --context kind-notaben-local get svc -A

local-argocd-password: ## Get local ArgoCD admin password
	@kubectl --context kind-notaben-local get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d
	@echo ""
