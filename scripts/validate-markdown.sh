#!/bin/bash

# Script to validate markdown files using markdownlint-cli2
# Reference: https://github.com/DavidAnson/markdownlint-cli2
# Usage: ./scripts/validate-markdown.sh [--fix]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check for --fix flag
FIX_MODE=false
FIX_FLAG=""
if [[ "$1" == "--fix" ]]; then
    FIX_MODE=true
    FIX_FLAG="--fix"
fi

# Determine action text
if [ "$FIX_MODE" = true ]; then
    ACTION="Fixing"
    ACTION_PAST="fixed"
else
    ACTION="Validating"
    ACTION_PAST="validated"
fi

echo -e "${BLUE}${ACTION} markdown files with markdownlint-cli2...${NC}"
echo "=================================================="

# Check if markdownlint-cli2 is installed
if ! command -v markdownlint-cli2 &> /dev/null; then
    echo -e "${RED}Error: markdownlint-cli2 is not installed.${NC}"
    echo -e "${YELLOW}Please install it using one of the following methods:${NC}"
    echo ""
    echo "  Using npm (recommended):"
    echo "    npm install -g markdownlint-cli2"
    echo ""
    echo "  Using Homebrew:"
    echo "    brew install markdownlint-cli2"
    echo ""
    echo "  Using yarn:"
    echo "    yarn global add markdownlint-cli2"
    echo ""
    echo "For more information, visit: https://github.com/DavidAnson/markdownlint-cli2"
    exit 1
fi

# Run markdownlint-cli2 on all markdown files
# The tool will use .markdownlint.yaml configuration file automatically
echo -e "${BLUE}Running markdownlint-cli2${FIX_FLAG:+ with --fix}...${NC}"
echo ""

# Run markdownlint command and capture the exit code
# Use '**/*.md' to check all markdown files recursively
# Exclude node_modules and other common directories that might contain vendor markdown
if markdownlint-cli2 $FIX_FLAG "**/*.md" "#node_modules" "#.build" "#vendor" 2>&1; then
    echo ""
    echo "=================================================="
    if [ "$FIX_MODE" = true ]; then
        echo -e "${GREEN}✓ All fixable markdown issues have been resolved!${NC}"
        echo ""
        echo -e "${YELLOW}Note: Some issues may require manual fixing:${NC}"
        echo -e "${YELLOW}  • Line length violations (MD013) - manually break long lines${NC}"
        echo -e "${YELLOW}  • Bare URLs (MD034) - convert to proper markdown links${NC}"
        echo ""
        echo -e "${BLUE}Run without --fix to see if any issues remain:${NC}"
        echo "  ./scripts/validate-markdown.sh"
    else
        echo -e "${GREEN}✓ All markdown files pass validation!${NC}"
    fi
    exit 0
else
    EXIT_CODE=$?
    echo ""
    echo "=================================================="
    if [ "$FIX_MODE" = true ]; then
        echo -e "${YELLOW}⚠ Fixed some issues, but manual intervention required for others.${NC}"
        echo ""
        echo -e "${YELLOW}Issues that require manual fixing:${NC}"
        echo -e "${YELLOW}  • Line length violations (MD013) - manually break long lines${NC}"
        echo -e "${YELLOW}  • Bare URLs (MD034) - convert to proper markdown links${NC}"
        echo ""
        echo -e "${BLUE}Run validation to see remaining issues:${NC}"
        echo "  ./scripts/validate-markdown.sh"
    else
        echo -e "${RED}✗ Validation failed! Markdown linting errors found.${NC}"
        echo ""
        echo -e "${YELLOW}Tips for fixing issues:${NC}"
        echo -e "${YELLOW}  • Line length: Maximum 120 characters per line${NC}"
        echo -e "${YELLOW}  • Break long lines at natural word boundaries${NC}"
        echo -e "${YELLOW}  • For lists that wrap, align continuation with content above${NC}"
        echo ""
        echo -e "${BLUE}To automatically fix some issues, run:${NC}"
        echo "  ./scripts/validate-markdown.sh --fix"
        echo ""
        echo "For rule documentation, visit:"
        echo "  https://github.com/DavidAnson/markdownlint/blob/main/doc/Rules.md"
    fi
    exit $EXIT_CODE
fi