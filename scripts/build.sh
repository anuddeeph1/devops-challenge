#!/bin/bash

# Build script for SimpleTimeService Docker image
# Usage: ./scripts/build.sh [tag]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🐳 Building SimpleTimeService Docker image${NC}"

# Get image tag from argument or use 'latest'
TAG="${1:-latest}"
IMAGE_NAME="simpletimeservice"
FULL_IMAGE="${IMAGE_NAME}:${TAG}"

# Change to app directory
cd "$(dirname "$0")/../app"

echo -e "${YELLOW}📦 Building image: ${FULL_IMAGE}${NC}"

# Build Docker image
docker build \
  --tag "${FULL_IMAGE}" \
  --label "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --label "org.opencontainers.image.version=${TAG}" \
  --label "org.opencontainers.image.title=SimpleTimeService" \
  --label "org.opencontainers.image.description=Microservice returning timestamp and client IP" \
  .

echo -e "${GREEN}✅ Build complete: ${FULL_IMAGE}${NC}"

# Show image size
docker images "${IMAGE_NAME}" | grep "${TAG}"

# Test the image
echo -e "${YELLOW}🧪 Testing image...${NC}"
CONTAINER_ID=$(docker run -d -p 8080:8080 "${FULL_IMAGE}")

# Wait for container to start
sleep 3

# Test health endpoint
if curl -f http://localhost:8080/health > /dev/null 2>&1; then
  echo -e "${GREEN}✅ Health check passed${NC}"
else
  echo -e "${RED}❌ Health check failed${NC}"
  docker logs "${CONTAINER_ID}"
  docker stop "${CONTAINER_ID}"
  exit 1
fi

# Test main endpoint
RESPONSE=$(curl -s http://localhost:8080/)
if echo "${RESPONSE}" | grep -q "timestamp"; then
  echo -e "${GREEN}✅ API test passed${NC}"
  echo "Response: ${RESPONSE}"
else
  echo -e "${RED}❌ API test failed${NC}"
  docker stop "${CONTAINER_ID}"
  exit 1
fi

# Cleanup
docker stop "${CONTAINER_ID}" > /dev/null
echo -e "${GREEN}✅ All tests passed!${NC}"

echo ""
echo -e "${GREEN}🚀 To run the container:${NC}"
echo "   docker run -p 8080:8080 ${FULL_IMAGE}"
echo ""
echo -e "${GREEN}📤 To push to registry:${NC}"
echo "   docker tag ${FULL_IMAGE} anuddeeph1/${FULL_IMAGE}"
echo "   docker push anuddeeph1/${FULL_IMAGE}"

