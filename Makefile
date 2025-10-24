.PHONY: help init plan apply destroy outputs status argocd-ui deploy-app check-app app-ui clean clean-all

# Variables
AWS_REGION := eu-central-1
CLUSTER_NAME := notaben-eks-cluster
ARGOCD_NAMESPACE := argocd
APP_NAMESPACE := nb-challenge

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
NC := \033[0m # No Color

##@ General

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Infrastructure

init: ## Initialize Terraform
	@echo "$(BLUE)Initializing Terraform...$(NC)"
	cd terraform && terraform init

plan: ## Show Terraform execution plan
	@echo "$(BLUE)Planning infrastructure changes...$(NC)"
	cd terraform && terraform plan

apply: ## Deploy infrastructure (EKS + ArgoCD)
	@echo "$(BLUE)Deploying infrastructure...$(NC)"
	@echo "$(YELLOW)This will take ~15 minutes$(NC)"
	cd terraform && terraform apply

destroy: ## Destroy all infrastructure
	@echo "$(YELLOW)WARNING: This will destroy all resources!$(NC)"
	@echo "Press Ctrl+C to cancel or wait 5 seconds to continue..."
	@sleep 5
	cd terraform && terraform destroy

outputs: ## Show Terraform outputs
	@echo "$(BLUE)Terraform outputs:$(NC)"
	cd terraform && terraform output

##@ Cluster Access

configure-kubectl: ## Configure kubectl for EKS cluster
	@echo "$(BLUE)Configuring kubectl...$(NC)"
	aws eks update-kubeconfig --region $(AWS_REGION) --name $(CLUSTER_NAME)
	@echo "$(GREEN)kubectl configured successfully$(NC)"

status: configure-kubectl ## Show cluster status (nodes, pods, services)
	@echo "$(BLUE)Nodes:$(NC)"
	@kubectl get nodes
	@echo "\n$(BLUE)Pods (all namespaces):$(NC)"
	@kubectl get pods -A
	@echo "\n$(BLUE)Services (all namespaces):$(NC)"
	@kubectl get svc -A

##@ ArgoCD

argocd-ui: configure-kubectl ## Access ArgoCD UI at https://localhost:8080
	@echo "$(GREEN)ArgoCD UI: https://localhost:8080$(NC)"
	@echo "$(YELLOW)Username: admin$(NC)"
	@echo "$(YELLOW)Password: Get from AWS Secrets Manager$(NC)"
	kubectl port-forward svc/argocd-server -n $(ARGOCD_NAMESPACE) 8080:443

##@ Application

deploy-app: configure-kubectl ## Deploy application via ArgoCD
	@echo "$(BLUE)Deploying application...$(NC)"
	@echo "$(YELLOW)Ensure Git repo URL is updated in argocd/application.yaml$(NC)"
	kubectl apply -f argocd/application.yaml
	@echo "$(GREEN)Application deployed. Check status: make check-app$(NC)"

check-app: configure-kubectl ## Check application status
	@echo "$(BLUE)ArgoCD Application:$(NC)"
	@kubectl get application simple-app -n $(ARGOCD_NAMESPACE)
	@echo "\n$(BLUE)Application Pods:$(NC)"
	@kubectl get pods -n $(APP_NAMESPACE) -l app=simple-app
	@echo "\n$(BLUE)Application Service:$(NC)"
	@kubectl get svc -n $(APP_NAMESPACE) simple-app

app-ui: configure-kubectl ## Access application at http://localhost:8081
	@echo "$(GREEN)Application: http://localhost:8081$(NC)"
	kubectl port-forward svc/simple-app -n $(APP_NAMESPACE) 8081:80

##@ Cleanup

clean: configure-kubectl ## Remove application only
	@echo "$(YELLOW)Removing application...$(NC)"
	kubectl delete -f argocd/application.yaml --ignore-not-found=true
	@echo "$(GREEN)Application removed$(NC)"

clean-all: clean destroy ## Remove everything (application + infrastructure)
	@echo "$(GREEN)All resources removed$(NC)"
