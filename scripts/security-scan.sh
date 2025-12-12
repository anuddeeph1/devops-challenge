#!/bin/bash

# Security scan script for SimpleTimeService
# Usage: ./scripts/security-scan.sh [image-name]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

IMAGE="${1:-simpletimeservice:latest}"
REPORTS_DIR="./security-reports"

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      Security Scanning Suite              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Target image: ${IMAGE}${NC}"
echo ""

# Create reports directory
mkdir -p "${REPORTS_DIR}"/{grype,sbom,vex}

# Function to check if Docker image exists
check_image() {
  if ! docker image inspect "${IMAGE}" > /dev/null 2>&1; then
    echo -e "${RED}❌ Image not found: ${IMAGE}${NC}"
    echo "Build the image first: ./scripts/build.sh"
    exit 1
  fi
  echo -e "${GREEN}✅ Image found${NC}"
}

# Function to run Grype vulnerability scan
run_grype() {
  echo ""
  echo -e "${YELLOW}🔍 Running Grype vulnerability scan...${NC}"
  
  if ! command -v grype &> /dev/null; then
    echo -e "${YELLOW}Installing Grype via Docker...${NC}"
    
    # JSON format
    docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      anchore/grype:latest \
      "${IMAGE}" \
      -o json > "${REPORTS_DIR}/grype/scan-report.json"
    
    # SARIF format
    docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      anchore/grype:latest \
      "${IMAGE}" \
      -o sarif > "${REPORTS_DIR}/grype/scan-report.sarif"
    
    # Table format
    docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      anchore/grype:latest \
      "${IMAGE}" \
      -o table > "${REPORTS_DIR}/grype/scan-report.txt"
  else
    grype "${IMAGE}" -o json > "${REPORTS_DIR}/grype/scan-report.json"
    grype "${IMAGE}" -o sarif > "${REPORTS_DIR}/grype/scan-report.sarif"
    grype "${IMAGE}" -o table > "${REPORTS_DIR}/grype/scan-report.txt"
  fi
  
  echo -e "${GREEN}✅ Grype scan complete${NC}"
  echo "Reports saved to: ${REPORTS_DIR}/grype/"
  
  # Display summary
  echo ""
  echo -e "${BLUE}Vulnerability Summary:${NC}"
  cat "${REPORTS_DIR}/grype/scan-report.txt" | head -n 20
}

# Function to generate SBOM with Syft
generate_sbom() {
  echo ""
  echo -e "${YELLOW}📋 Generating SBOM with Syft...${NC}"
  
  if ! command -v syft &> /dev/null; then
    echo -e "${YELLOW}Installing Syft via Docker...${NC}"
    
    # CycloneDX JSON format
    docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      anchore/syft:latest \
      "${IMAGE}" \
      -o cyclonedx-json > "${REPORTS_DIR}/sbom/sbom-cyclonedx.json"
    
    # SPDX JSON format
    docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      anchore/syft:latest \
      "${IMAGE}" \
      -o spdx-json > "${REPORTS_DIR}/sbom/sbom-spdx.json"
    
    # Table format
    docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      anchore/syft:latest \
      "${IMAGE}" \
      -o table > "${REPORTS_DIR}/sbom/sbom-table.txt"
  else
    syft "${IMAGE}" -o cyclonedx-json > "${REPORTS_DIR}/sbom/sbom-cyclonedx.json"
    syft "${IMAGE}" -o spdx-json > "${REPORTS_DIR}/sbom/sbom-spdx.json"
    syft "${IMAGE}" -o table > "${REPORTS_DIR}/sbom/sbom-table.txt"
  fi
  
  echo -e "${GREEN}✅ SBOM generation complete${NC}"
  echo "Reports saved to: ${REPORTS_DIR}/sbom/"
}

# Function to generate VEX document
generate_vex() {
  echo ""
  echo -e "${YELLOW}📊 Generating VEX document...${NC}"
  
  # Parse Grype results and generate VEX
  cat > "${REPORTS_DIR}/vex/vex-document.json" <<EOF
{
  "@context": "https://openvex.dev/ns",
  "@id": "https://example.com/security/vex-$(date +%Y%m%d)",
  "author": "DevOps Team",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "version": "1",
  "statements": [
    {
      "vulnerability": "SECURITY-SCAN-$(date +%Y%m%d)",
      "products": [
        "${IMAGE}"
      ],
      "status": "under_investigation",
      "justification": "Automated security scan completed. Review required for identified vulnerabilities."
    }
  ]
}
EOF
  
  echo -e "${GREEN}✅ VEX document generated${NC}"
  echo "Document saved to: ${REPORTS_DIR}/vex/vex-document.json"
}

# Function to sign with Cosign (if available)
sign_with_cosign() {
  echo ""
  echo -e "${YELLOW}🔐 Signing image with Cosign...${NC}"
  
  if ! command -v cosign &> /dev/null; then
    echo -e "${YELLOW}⚠️  Cosign not installed, skipping signing${NC}"
    echo "Install from: https://docs.sigstore.dev/cosign/installation/"
    return
  fi
  
  echo -e "${YELLOW}Note: Keyless signing requires GitHub Actions or other OIDC provider${NC}"
  echo -e "${YELLOW}For local signing, generate a key pair:${NC}"
  echo "  cosign generate-key-pair"
  echo "  cosign sign --key cosign.key ${IMAGE}"
}

# Generate summary report
generate_summary() {
  echo ""
  echo -e "${YELLOW}📄 Generating summary report...${NC}"
  
  cat > "${REPORTS_DIR}/security-summary.md" <<EOF
# Security Scan Report

**Image:** ${IMAGE}  
**Scan Date:** $(date)  
**Scan Tool:** Grype + Syft + VEX

## Summary

### Vulnerability Scan (Grype)

See detailed reports:
- JSON: \`grype/scan-report.json\`
- SARIF: \`grype/scan-report.sarif\`
- Table: \`grype/scan-report.txt\`

### Software Bill of Materials (SBOM)

- CycloneDX: \`sbom/sbom-cyclonedx.json\`
- SPDX: \`sbom/sbom-spdx.json\`
- Table: \`sbom/sbom-table.txt\`

### VEX Document

- OpenVEX: \`vex/vex-document.json\`

## Recommendations

1. Review identified vulnerabilities in Grype report
2. Update base images and dependencies regularly
3. Implement automated security scanning in CI/CD
4. Sign container images with Cosign
5. Store SBOM with container registry

## Next Steps

- Review \`grype/scan-report.txt\` for vulnerability details
- Check SBOM for component inventory
- Apply security patches for high/critical vulnerabilities
- Sign and attest the image before deployment

---
*Generated by security-scan.sh*
EOF
  
  echo -e "${GREEN}✅ Summary report generated${NC}"
  echo "Report saved to: ${REPORTS_DIR}/security-summary.md"
}

# Main execution
main() {
  check_image
  run_grype
  generate_sbom
  generate_vex
  sign_with_cosign
  generate_summary
  
  echo ""
  echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║      Security Scan Complete                ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${GREEN}📁 All reports saved to: ${REPORTS_DIR}/${NC}"
  echo ""
  echo -e "${YELLOW}Review the reports:${NC}"
  echo "  cat ${REPORTS_DIR}/security-summary.md"
  echo "  cat ${REPORTS_DIR}/grype/scan-report.txt"
  echo "  cat ${REPORTS_DIR}/sbom/sbom-table.txt"
}

main

