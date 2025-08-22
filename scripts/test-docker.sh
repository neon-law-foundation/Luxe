#!/bin/bash

# test-docker.sh - Test that all Docker files in Sources directory build correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Testing Docker builds in Sources directory...${NC}"

# Find all Dockerfiles in Sources directory
DOCKERFILES=$(find Sources -name "Dockerfile" -type f)

if [ -z "$DOCKERFILES" ]; then
    echo -e "${YELLOW}No Dockerfiles found in Sources directory${NC}"
    exit 0
fi

# Track results
TOTAL=0
PASSED=0
FAILED=0

# Test each Dockerfile
for dockerfile in $DOCKERFILES; do
    TOTAL=$((TOTAL + 1))
    dir=$(dirname "$dockerfile")
    target=$(basename "$dir")
    
    echo -e "\n${YELLOW}Testing Docker build for $target...${NC}"
    echo "Building from: $dockerfile"
    
    # Set up version information for local builds
    GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "local")
    GIT_TAG=$(git describe --tags --exact-match 2>/dev/null || echo "dev")
    BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Build the Docker image with version info
    if docker build \
        --build-arg GIT_COMMIT="$GIT_COMMIT" \
        --build-arg GIT_TAG="$GIT_TAG" \
        --build-arg BUILD_DATE="$BUILD_DATE" \
        -t "luxe-$target:$GIT_COMMIT" \
        -t "luxe-$target:test" \
        -f "$dockerfile" .; then
        echo -e "${GREEN}✓ $target build succeeded${NC}"
        PASSED=$((PASSED + 1))
        
        echo "  Version: $GIT_TAG ($GIT_COMMIT)"
        echo "  Build Date: $BUILD_DATE"
        
        # Clean up the test images
        docker rmi "luxe-$target:test" >/dev/null 2>&1 || true
        docker rmi "luxe-$target:$GIT_COMMIT" >/dev/null 2>&1 || true
    else
        echo -e "${RED}✗ $target build failed${NC}"
        FAILED=$((FAILED + 1))
    fi
done

# Summary
echo -e "\n${YELLOW}=== Docker Build Test Summary ===${NC}"
echo "Total targets tested: $TOTAL"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"

if [ $FAILED -eq 0 ]; then
    echo -e "\n${GREEN}All Docker builds passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some Docker builds failed!${NC}"
    exit 1
fi