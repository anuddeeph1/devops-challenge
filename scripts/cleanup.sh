#!/bin/bash

# Cleanup script for SimpleTimeService
# Usage: ./scripts/cleanup.sh [terraform|kubernetes|docker|all]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

CLEANUP_TYPE="${1:-all}"

echo -e "${YELLOW}⚠️  SimpleTimeService Cleanup Script${NC}"
echo ""

# Function to cleanup Kubernetes resources
cleanup_kubernetes() {
  echo -e "${YELLOW}☸️  Cleaning up Kubernetes resources...${NC}"
  
  if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl not found, skipping Kubernetes cleanup${NC}"
    return
  fi
  
  if ! kubectl cluster-info &> /dev/null; then
    echo -e "${YELLOW}Not connected to Kubernetes cluster, skipping${NC}"
    return
  fi
  
  # Delete namespace (this will delete all resources in it)
  if kubectl get namespace simpletimeservice &> /dev/null; then
    echo -e "${YELLOW}Deleting namespace simpletimeservice...${NC}"
    kubectl delete namespace simpletimeservice --timeout=5m
    echo -e "${GREEN}✅ Kubernetes resources deleted${NC}"
  else
    echo -e "${YELLOW}Namespace simpletimeservice not found${NC}"
  fi
}

# Function to cleanup Terraform resources
cleanup_terraform() {
  echo ""
  echo -e "${YELLOW}🏗️  Cleaning up Terraform resources...${NC}"
  
  cd "$(dirname "$0")/../terraform"
  
  if [ ! -f "terraform.tfstate" ] && [ ! -f ".terraform/terraform.tfstate" ]; then
    echo -e "${YELLOW}No Terraform state found, skipping${NC}"
    cd - > /dev/null
    return
  fi
  
  echo -e "${RED}⚠️  WARNING: This will destroy ALL infrastructure in AWS${NC}"
  echo -e "${RED}This includes: VPC, EKS cluster, Load Balancer, etc.${NC}"
  echo ""
  read -p "Are you sure? Type 'yes' to continue: " confirm
  
  if [ "$confirm" != "yes" ]; then
    echo -e "${YELLOW}Terraform cleanup cancelled${NC}"
    cd - > /dev/null
    return
  fi
  
  echo -e "${YELLOW}Running terraform destroy...${NC}"
  terraform destroy -auto-approve || {
    echo -e "${RED}❌ Terraform destroy failed${NC}"
    echo "You may need to manually delete resources in AWS Console"
  }
  
  echo -e "${GREEN}✅ Terraform resources destroyed${NC}"
  
  # Clean up backend resources
  echo ""
  read -p "Delete S3 backend and DynamoDB table? (yes/no): " delete_backend
  
  if [ "$delete_backend" == "yes" ]; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    BUCKET_NAME="simpletimeservice-terraform-state-${ACCOUNT_ID}"
    TABLE_NAME="simpletimeservice-terraform-locks"
    
    echo -e "${YELLOW}Deleting S3 bucket: ${BUCKET_NAME}${NC}"
    aws s3 rm "s3://${BUCKET_NAME}" --recursive 2>/dev/null || true
    aws s3 rb "s3://${BUCKET_NAME}" 2>/dev/null || true
    
    echo -e "${YELLOW}Deleting DynamoDB table: ${TABLE_NAME}${NC}"
    aws dynamodb delete-table --table-name "${TABLE_NAME}" --region us-west-1 2>/dev/null || true
    
    echo -e "${GREEN}✅ Backend resources deleted${NC}"
  fi
  
  cd - > /dev/null
}

# Function to cleanup Docker resources
cleanup_docker() {
  echo ""
  echo -e "${YELLOW}🐳 Cleaning up Docker resources...${NC}"
  
  # Stop running containers
  CONTAINERS=$(docker ps -q --filter "ancestor=simpletimeservice")
  if [ -n "$CONTAINERS" ]; then
    echo -e "${YELLOW}Stopping running containers...${NC}"
    docker stop $CONTAINERS
    echo -e "${GREEN}✅ Containers stopped${NC}"
  fi
  
  # Remove stopped containers
  STOPPED=$(docker ps -aq --filter "ancestor=simpletimeservice")
  if [ -n "$STOPPED" ]; then
    echo -e "${YELLOW}Removing stopped containers...${NC}"
    docker rm $STOPPED
    echo -e "${GREEN}✅ Containers removed${NC}"
  fi
  
  # Remove images
  IMAGES=$(docker images -q simpletimeservice)
  if [ -n "$IMAGES" ]; then
    read -p "Remove local Docker images? (yes/no): " remove_images
    if [ "$remove_images" == "yes" ]; then
      echo -e "${YELLOW}Removing images...${NC}"
      docker rmi $IMAGES
      echo -e "${GREEN}✅ Images removed${NC}"
    fi
  fi
}

# Function to cleanup local files
cleanup_local() {
  echo ""
  echo -e "${YELLOW}🗑️  Cleaning up local files...${NC}"
  
  # Remove Terraform files
  if [ -d "terraform/.terraform" ]; then
    echo -e "${YELLOW}Removing Terraform cache...${NC}"
    rm -rf terraform/.terraform
    rm -f terraform/.terraform.lock.hcl
    rm -f terraform/tfplan
  fi
  
  # Remove security reports
  if [ -d "security-reports" ]; then
    read -p "Remove security reports? (yes/no): " remove_reports
    if [ "$remove_reports" == "yes" ]; then
      rm -rf security-reports
      echo -e "${GREEN}✅ Security reports removed${NC}"
    fi
  fi
  
  # Remove Go build artifacts
  if [ -d "app" ]; then
    rm -f app/simpletimeservice
    rm -f app/coverage.out
    rm -f app/coverage.html
    echo -e "${GREEN}✅ Build artifacts removed${NC}"
  fi
}

# Main cleanup logic
main() {
  echo -e "${YELLOW}Cleanup type: ${CLEANUP_TYPE}${NC}"
  echo ""
  
  case "$CLEANUP_TYPE" in
    kubernetes)
      cleanup_kubernetes
      ;;
    terraform)
      cleanup_terraform
      ;;
    docker)
      cleanup_docker
      ;;
    all)
      cleanup_kubernetes
      cleanup_terraform
      cleanup_docker
      cleanup_local
      ;;
    *)
      echo -e "${RED}❌ Invalid cleanup type: $CLEANUP_TYPE${NC}"
      echo "Usage: $0 [terraform|kubernetes|docker|all]"
      exit 1
      ;;
  esac
  
  echo ""
  echo -e "${GREEN}✅ Cleanup complete${NC}"
}

main

