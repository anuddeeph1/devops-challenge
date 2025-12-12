#!/bin/bash

# Test script for SimpleTimeService
# Usage: ./scripts/test.sh [local|remote] [endpoint]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TEST_TYPE="${1:-local}"
ENDPOINT="${2:-http://localhost:8080}"

echo -e "${GREEN}🧪 Testing SimpleTimeService${NC}"
echo ""

# Function to test endpoint
test_endpoint() {
  local url="$1"
  local description="$2"
  
  echo -e "${YELLOW}Testing: ${description}${NC}"
  echo "URL: ${url}"
  
  response=$(curl -s -w "\n%{http_code}" "${url}" 2>/dev/null)
  http_code=$(echo "${response}" | tail -n1)
  body=$(echo "${response}" | sed '$d')
  
  if [ "${http_code}" == "200" ]; then
    echo -e "${GREEN}✅ HTTP ${http_code}${NC}"
    echo "Response: ${body}"
    return 0
  else
    echo -e "${RED}❌ HTTP ${http_code}${NC}"
    echo "Response: ${body}"
    return 1
  fi
}

# Test local Docker container
test_local() {
  echo -e "${YELLOW}🐳 Testing local Docker container${NC}"
  
  # Check if container is running
  if ! docker ps | grep -q simpletimeservice; then
    echo -e "${RED}❌ No running container found${NC}"
    echo "Start container with: docker run -d -p 8080:8080 simpletimeservice:latest"
    exit 1
  fi
  
  # Test health endpoint
  test_endpoint "http://localhost:8080/health" "Health check"
  echo ""
  
  # Test main endpoint
  test_endpoint "http://localhost:8080/" "Main API endpoint"
  echo ""
  
  # Test with X-Forwarded-For header
  echo -e "${YELLOW}Testing with X-Forwarded-For header${NC}"
  response=$(curl -s -H "X-Forwarded-For: 203.0.113.42" http://localhost:8080/)
  if echo "${response}" | grep -q "203.0.113.42"; then
    echo -e "${GREEN}✅ X-Forwarded-For handling works${NC}"
    echo "Response: ${response}"
  else
    echo -e "${RED}❌ X-Forwarded-For handling failed${NC}"
    echo "Response: ${response}"
  fi
}

# Test remote deployment
test_remote() {
  echo -e "${YELLOW}☁️  Testing remote deployment${NC}"
  
  # Get ALB endpoint if not provided
  if [ "${ENDPOINT}" == "http://localhost:8080" ]; then
    cd "$(dirname "$0")/../terraform"
    ENDPOINT="http://$(terraform output -raw alb_dns_name 2>/dev/null || echo 'localhost:8080')"
    cd - > /dev/null
  fi
  
  echo "Testing endpoint: ${ENDPOINT}"
  echo ""
  
  # Test health endpoint
  test_endpoint "${ENDPOINT}/health" "Health check"
  echo ""
  
  # Test main endpoint
  test_endpoint "${ENDPOINT}/" "Main API endpoint"
  echo ""
  
  # Test load balancer behavior
  echo -e "${YELLOW}Testing load balancer (5 requests)${NC}"
  for i in {1..5}; do
    echo -n "Request $i: "
    curl -s "${ENDPOINT}/" | jq -r '.ip' || echo "Failed"
  done
}

# Load test
load_test() {
  echo ""
  echo -e "${YELLOW}⚡ Running load test${NC}"
  
  if ! command -v ab &> /dev/null; then
    echo -e "${RED}❌ Apache Bench (ab) not found${NC}"
    echo "Install: sudo apt-get install apache2-utils"
    return
  fi
  
  echo "Running 1000 requests with 10 concurrent connections..."
  ab -n 1000 -c 10 "${ENDPOINT}/" 2>/dev/null | grep -E "(Requests per second|Time per request|Transfer rate)"
}

# Main test logic
main() {
  case "$TEST_TYPE" in
    local)
      test_local
      ;;
    remote)
      test_remote
      load_test
      ;;
    *)
      echo -e "${RED}❌ Invalid test type: $TEST_TYPE${NC}"
      echo "Usage: $0 [local|remote] [endpoint]"
      exit 1
      ;;
  esac
  
  echo ""
  echo -e "${GREEN}✅ All tests completed${NC}"
}

main

