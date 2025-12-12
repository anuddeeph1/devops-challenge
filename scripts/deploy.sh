#!/bin/bash

# Deployment script for SimpleTimeService
# Usage: ./scripts/deploy.sh [terraform|kubernetes|all]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

DEPLOY_TYPE="${1:-all}"

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   SimpleTimeService Deployment Script     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
  echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"
  
  local missing_tools=()
  
  if [ "$DEPLOY_TYPE" == "terraform" ] || [ "$DEPLOY_TYPE" == "all" ]; then
    command_exists terraform || missing_tools+=("terraform")
    command_exists aws || missing_tools+=("aws-cli")
  fi
  
  if [ "$DEPLOY_TYPE" == "kubernetes" ] || [ "$DEPLOY_TYPE" == "all" ]; then
    command_exists kubectl || missing_tools+=("kubectl")
  fi
  
  if [ ${#missing_tools[@]} -gt 0 ]; then
    echo -e "${RED}❌ Missing required tools: ${missing_tools[*]}${NC}"
    echo ""
    echo "Please install:"
    for tool in "${missing_tools[@]}"; do
      echo "  - $tool"
    done
    exit 1
  fi
  
  echo -e "${GREEN}✅ All prerequisites met${NC}"
}

# Deploy Terraform infrastructure
deploy_terraform() {
  echo ""
  echo -e "${YELLOW}🏗️  Deploying Terraform infrastructure...${NC}"
  
  cd "$(dirname "$0")/../terraform"
  
  # Check AWS credentials
  if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo -e "${RED}❌ AWS credentials not configured${NC}"
    echo "Run: aws configure"
    exit 1
  fi
  
  echo -e "${BLUE}Account: $(aws sts get-caller-identity --query Account --output text)${NC}"
  echo -e "${BLUE}Region: us-west-1${NC}"
  
  # Initialize Terraform
  echo -e "${YELLOW}📦 Initializing Terraform...${NC}"
  terraform init
  
  # Validate configuration
  echo -e "${YELLOW}✅ Validating configuration...${NC}"
  terraform validate
  
  # Plan deployment
  echo -e "${YELLOW}📋 Planning deployment...${NC}"
  terraform plan -out=tfplan
  
  # Ask for confirmation
  echo ""
  echo -e "${YELLOW}⚠️  Ready to deploy infrastructure (this will incur AWS costs)${NC}"
  read -p "Continue? (yes/no): " confirm
  
  if [ "$confirm" != "yes" ]; then
    echo -e "${RED}❌ Deployment cancelled${NC}"
    exit 1
  fi
  
  # Apply Terraform
  echo -e "${YELLOW}🚀 Applying Terraform...${NC}"
  terraform apply tfplan
  
  # Configure kubectl
  echo -e "${YELLOW}🔧 Configuring kubectl...${NC}"
  CLUSTER_NAME=$(terraform output -raw cluster_name)
  aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region us-west-1
  
  echo -e "${GREEN}✅ Terraform deployment complete${NC}"
  
  # Display outputs
  echo ""
  echo -e "${GREEN}📊 Deployment Information:${NC}"
  terraform output
  
  cd - > /dev/null
}

# Deploy Kubernetes manifests
deploy_kubernetes() {
  echo ""
  echo -e "${YELLOW}☸️  Deploying Kubernetes manifests...${NC}"
  
  cd "$(dirname "$0")/../kubernetes"
  
  # Check cluster connection
  if ! kubectl cluster-info > /dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to Kubernetes cluster${NC}"
    echo "Run: aws eks update-kubeconfig --name simpletimeservice-cluster --region us-west-1"
    exit 1
  fi
  
  echo -e "${BLUE}Cluster: $(kubectl config current-context)${NC}"
  
  # Apply manifests
  echo -e "${YELLOW}📦 Creating namespace...${NC}"
  kubectl apply -f namespace.yaml
  
  echo -e "${YELLOW}🔐 Creating service account...${NC}"
  kubectl apply -f serviceaccount.yaml
  
  echo -e "${YELLOW}🚀 Deploying application...${NC}"
  kubectl apply -f deployment.yaml
  
  echo -e "${YELLOW}🌐 Creating service...${NC}"
  kubectl apply -f service.yaml
  
  echo -e "${YELLOW}📊 Setting up autoscaling...${NC}"
  kubectl apply -f hpa.yaml
  
  # Wait for rollout
  echo -e "${YELLOW}⏳ Waiting for deployment to be ready...${NC}"
  kubectl rollout status deployment/simpletimeservice -n simpletimeservice --timeout=5m
  
  echo -e "${GREEN}✅ Kubernetes deployment complete${NC}"
  
  # Display status
  echo ""
  echo -e "${GREEN}📊 Application Status:${NC}"
  kubectl get pods -n simpletimeservice
  echo ""
  kubectl get svc -n simpletimeservice
  echo ""
  kubectl get hpa -n simpletimeservice
  
  cd - > /dev/null
}

# Main deployment logic
main() {
  check_prerequisites
  
  case "$DEPLOY_TYPE" in
    terraform)
      deploy_terraform
      ;;
    kubernetes)
      deploy_kubernetes
      ;;
    all)
      deploy_terraform
      deploy_kubernetes
      ;;
    *)
      echo -e "${RED}❌ Invalid deployment type: $DEPLOY_TYPE${NC}"
      echo "Usage: $0 [terraform|kubernetes|all]"
      exit 1
      ;;
  esac
  
  echo ""
  echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║     Deployment Completed Successfully     ║${NC}"
  echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
  echo ""
  
  if [ "$DEPLOY_TYPE" == "terraform" ] || [ "$DEPLOY_TYPE" == "all" ]; then
    echo -e "${BLUE}🌐 Access your application:${NC}"
    cd "$(dirname "$0")/../terraform"
    ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "N/A")
    if [ "$ALB_DNS" != "N/A" ]; then
      echo "   http://${ALB_DNS}/"
    fi
    cd - > /dev/null
  fi
}

main

