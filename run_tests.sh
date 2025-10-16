#!/bin/bash

# BrownClaw Test Runner Script
# Usage: ./run_tests.sh [option]

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 BrownClaw Test Suite Runner${NC}\n"

# Function to display help
show_help() {
    echo "Usage: ./run_tests.sh [option]"
    echo ""
    echo "Options:"
    echo "  all          Run all tests"
    echo "  models       Run model tests only"
    echo "  services     Run service tests only"
    echo "  widgets      Run widget tests only"
    echo "  integration  Run integration tests only"
    echo "  new          Run all newly created tests (models + services + widgets + integration)"
    echo "  coverage     Run tests with coverage report"
    echo "  help         Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./run_tests.sh new         # Run all new tests"
    echo "  ./run_tests.sh models      # Run only model tests"
    echo "  ./run_tests.sh coverage    # Generate coverage report"
}

# Main test execution
case "$1" in
    all)
        echo -e "${YELLOW}Running all tests...${NC}"
        flutter test
        ;;
    models)
        echo -e "${YELLOW}Running model tests...${NC}"
        flutter test test/models/
        ;;
    services)
        echo -e "${YELLOW}Running service tests...${NC}"
        flutter test test/services/
        ;;
    widgets)
        echo -e "${YELLOW}Running widget tests...${NC}"
        flutter test test/widgets/
        ;;
    integration)
        echo -e "${YELLOW}Running integration tests...${NC}"
        flutter test test/integration/
        ;;
    new)
        echo -e "${YELLOW}Running newly created tests...${NC}"
        flutter test test/models/ test/services/ test/widgets/ test/integration/
        ;;
    coverage)
        echo -e "${YELLOW}Running tests with coverage...${NC}"
        flutter test --coverage test/models/ test/services/ test/integration/
        echo -e "\n${GREEN}✓ Coverage report generated in coverage/lcov.info${NC}"
        echo -e "${BLUE}To view HTML coverage report:${NC}"
        echo -e "  genhtml coverage/lcov.info -o coverage/html"
        echo -e "  open coverage/html/index.html"
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        echo -e "${YELLOW}Running all new tests by default...${NC}"
        flutter test test/models/ test/services/ test/widgets/ test/integration/
        ;;
    *)
        echo -e "${YELLOW}Unknown option: $1${NC}"
        show_help
        exit 1
        ;;
esac

# Display summary
if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓ All tests passed!${NC}"
else
    echo -e "\n${YELLOW}Some tests failed. Check output above.${NC}"
    exit 1
fi
