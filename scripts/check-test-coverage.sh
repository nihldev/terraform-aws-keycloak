#!/usr/bin/env bash
#
# Terraform Test Coverage Checker
#
# This script analyzes test coverage for the Keycloak module by checking:
# 1. Resource coverage - which resources are created in tests
# 2. Variable coverage - which variables are tested with non-default values
# 3. Output coverage - which outputs are validated in tests
# 4. Example coverage - which examples have corresponding tests

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "═══════════════════════════════════════════════════════════════"
echo "           TERRAFORM TEST COVERAGE ANALYSIS"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Change to repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

#############################################################################
# 1. RESOURCE COVERAGE
#############################################################################
echo -e "${BLUE}[1/4] Resource Coverage Analysis${NC}"
echo "────────────────────────────────────────────────────────────────"

# Count total resources defined in module
MODULE_DIR="modules/keycloak"
TOTAL_RESOURCES=$(grep -r "^resource " "$MODULE_DIR"/*.tf 2>/dev/null | wc -l | tr -d ' ')

echo "Total resources defined in module: $TOTAL_RESOURCES"
echo ""

# List all resources
echo "Resources in module:"
grep -h "^resource " "$MODULE_DIR"/*.tf 2>/dev/null | \
    sed 's/resource "\([^"]*\)" "\([^"]*\)".*/  • \1.\2/' | \
    sort | \
    uniq

echo ""
echo "Note: Resource coverage is validated by successful test execution."
echo "Run 'terraform test' to verify all resources can be created."
echo ""

#############################################################################
# 2. VARIABLE COVERAGE
#############################################################################
echo -e "${BLUE}[2/4] Variable Coverage Analysis${NC}"
echo "────────────────────────────────────────────────────────────────"

# Count total variables
TOTAL_VARS=$(grep -c "^variable " "$MODULE_DIR/variables.tf" 2>/dev/null || echo "0")
echo "Total variables in module: $TOTAL_VARS"
echo ""

# Check which variables are tested with custom values
echo "Checking variable test coverage..."

# Extract variables from module
MODULE_VARS=$(grep "^variable " "$MODULE_DIR/variables.tf" | awk '{print $2}' | tr -d '"')

# Check test files for variable overrides
TESTED_VARS=0
UNTESTED_VARS=""

for var in $MODULE_VARS; do
    # Check if variable is used in any test file or example
    if grep -r "$var" tests/*.tftest.hcl examples/*/main.tf examples/*/variables.tf >/dev/null 2>&1; then
        ((TESTED_VARS++)) || true
    else
        UNTESTED_VARS="$UNTESTED_VARS\n  • $var"
    fi
done

VAR_COVERAGE=$((TESTED_VARS * 100 / TOTAL_VARS))

echo "Variables referenced in tests/examples: $TESTED_VARS / $TOTAL_VARS ($VAR_COVERAGE%)"

if [ -n "$UNTESTED_VARS" ]; then
    echo -e "${YELLOW}Variables never referenced in tests:${NC}"
    echo -e "$UNTESTED_VARS"
else
    echo -e "${GREEN}All variables are referenced in tests/examples!${NC}"
fi

echo ""

#############################################################################
# 3. OUTPUT COVERAGE
#############################################################################
echo -e "${BLUE}[3/4] Output Coverage Analysis${NC}"
echo "────────────────────────────────────────────────────────────────"

# Count total outputs
TOTAL_OUTPUTS=$(grep -c "^output " "$MODULE_DIR/outputs.tf" 2>/dev/null || echo "0")
echo "Total outputs in module: $TOTAL_OUTPUTS"
echo ""

# Check which outputs are validated in tests
OUTPUT_TEST_FILE="tests/outputs_validation.tftest.hcl"
if [ -f "$OUTPUT_TEST_FILE" ]; then
    VALIDATED_OUTPUTS=$(grep -c "output\." "$OUTPUT_TEST_FILE" 2>/dev/null || echo "0")
    OUTPUT_COVERAGE=$((VALIDATED_OUTPUTS * 100 / TOTAL_OUTPUTS))

    echo "Outputs validated in tests: $VALIDATED_OUTPUTS / $TOTAL_OUTPUTS ($OUTPUT_COVERAGE%)"

    # Find outputs not validated
    MODULE_OUTPUTS=$(grep "^output " "$MODULE_DIR/outputs.tf" | awk '{print $2}' | tr -d '"')

    echo ""
    echo "Outputs validation status:"
    for output in $MODULE_OUTPUTS; do
        if grep "output\.$output" "$OUTPUT_TEST_FILE" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} $output - validated"
        else
            echo -e "  ${YELLOW}○${NC} $output - not validated"
        fi
    done
else
    echo -e "${RED}No output validation test found!${NC}"
    echo "Create tests/outputs_validation.tftest.hcl to validate outputs"
fi

echo ""

#############################################################################
# 4. EXAMPLE COVERAGE
#############################################################################
echo -e "${BLUE}[4/4] Example Test Coverage${NC}"
echo "────────────────────────────────────────────────────────────────"

# Count examples
EXAMPLE_DIRS=$(find examples -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
echo "Total examples: $EXAMPLE_DIRS"
echo ""

# Check which examples have tests
TESTED_EXAMPLES=0
UNTESTED_EXAMPLES=""

for example_dir in examples/*/; do
    example_name=$(basename "$example_dir")
    test_file="tests/examples_${example_name}.tftest.hcl"

    if [ -f "$test_file" ]; then
        echo -e "  ${GREEN}✓${NC} $example_name - has test"
        ((TESTED_EXAMPLES++)) || true
    else
        echo -e "  ${YELLOW}○${NC} $example_name - no test"
        UNTESTED_EXAMPLES="$UNTESTED_EXAMPLES\n  • $example_name"
    fi
done

EXAMPLE_COVERAGE=$((TESTED_EXAMPLES * 100 / EXAMPLE_DIRS))
echo ""
echo "Examples with tests: $TESTED_EXAMPLES / $EXAMPLE_DIRS ($EXAMPLE_COVERAGE%)"

if [ -n "$UNTESTED_EXAMPLES" ]; then
    echo -e "${YELLOW}Examples without tests:${NC}"
    echo -e "$UNTESTED_EXAMPLES"
fi

echo ""

#############################################################################
# 5. SUMMARY
#############################################################################
echo "═══════════════════════════════════════════════════════════════"
echo -e "${BLUE}               COVERAGE SUMMARY${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo ""

printf "%-30s %3d%%\n" "Variable Coverage:" "$VAR_COVERAGE"
printf "%-30s %3d%%\n" "Output Validation Coverage:" "$OUTPUT_COVERAGE"
printf "%-30s %3d%%\n" "Example Test Coverage:" "$EXAMPLE_COVERAGE"

echo ""

# Overall assessment
TOTAL_COVERAGE=$(( (VAR_COVERAGE + OUTPUT_COVERAGE + EXAMPLE_COVERAGE) / 3 ))

if [ "$TOTAL_COVERAGE" -ge 80 ]; then
    echo -e "${GREEN}Overall Assessment: EXCELLENT ($TOTAL_COVERAGE%)${NC}"
elif [ "$TOTAL_COVERAGE" -ge 60 ]; then
    echo -e "${YELLOW}Overall Assessment: GOOD ($TOTAL_COVERAGE%)${NC}"
elif [ "$TOTAL_COVERAGE" -ge 40 ]; then
    echo -e "${YELLOW}Overall Assessment: FAIR ($TOTAL_COVERAGE%)${NC}"
else
    echo -e "${RED}Overall Assessment: NEEDS IMPROVEMENT ($TOTAL_COVERAGE%)${NC}"
fi

echo ""

#############################################################################
# 6. RECOMMENDATIONS
#############################################################################
echo "═══════════════════════════════════════════════════════════════"
echo -e "${BLUE}               RECOMMENDATIONS${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo ""

if [ "$OUTPUT_COVERAGE" -lt 100 ]; then
    echo "• Add output validation assertions to tests/outputs_validation.tftest.hcl"
fi

if [ "$EXAMPLE_COVERAGE" -lt 100 ]; then
    echo "• Create test files for untested examples"
fi

if [ "$VAR_COVERAGE" -lt 80 ]; then
    echo "• Consider adding tests that exercise more variable combinations"
fi

echo "• Run 'terraform test -verbose' to verify all resources create successfully"
echo "• Review test assertions to ensure they validate critical behaviors"
echo ""

echo "═══════════════════════════════════════════════════════════════"
