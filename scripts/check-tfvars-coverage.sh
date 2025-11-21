#!/usr/bin/env bash
#
# check-tfvars-complete.sh
# Validates that terraform.tfvars.example includes all variables defined in variables.tf
#
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Checking terraform.tfvars.example completeness..."

# Find all example directories
EXAMPLES_DIR="examples"
MISSING_VARS_FOUND=false

# Check each example directory
for EXAMPLE in $(find "$EXAMPLES_DIR" -type d -mindepth 1 -maxdepth 1); do
    EXAMPLE_NAME=$(basename "$EXAMPLE")
    TFVARS_EXAMPLE="$EXAMPLE/terraform.tfvars.example"

    if [[ ! -f "$TFVARS_EXAMPLE" ]]; then
        echo -e "${YELLOW}⚠ Warning: No terraform.tfvars.example found in $EXAMPLE${NC}"
        continue
    fi

    echo ""
    echo "Checking: $EXAMPLE_NAME"
    echo "----------------------------------------"

    # Find all modules referenced in the example
    MODULES=$(grep -h "source.*=.*modules/" "$EXAMPLE"/*.tf 2>/dev/null | sed 's/.*"\(.*\)".*/\1/' | sort -u || true)

    if [[ -z "$MODULES" ]]; then
        echo -e "${YELLOW}  No module sources found${NC}"
        continue
    fi

    # For each module, check if all variables are documented in tfvars.example
    for MODULE_PATH in $MODULES; do
        # Remove leading ../../ or ../
        MODULE_PATH=$(echo "$MODULE_PATH" | sed 's|^\.*/||')
        VARIABLES_FILE="$MODULE_PATH/variables.tf"

        if [[ ! -f "$VARIABLES_FILE" ]]; then
            continue
        fi

        # Extract variable names from variables.tf
        DEFINED_VARS=$(grep '^variable ' "$VARIABLES_FILE" | awk '{print $2}' | tr -d '"' | sort)

        # Extract variable names from terraform.tfvars.example (commented or uncommented)
        DOCUMENTED_VARS=$(grep -E '^\s*(#\s*)?[a-z_]' "$TFVARS_EXAMPLE" | grep -v '^#####' | sed 's/^[# ]*//' | cut -d'=' -f1 | tr -d ' ' | sort | uniq)

        # Find missing variables
        MISSING_VARS=$(comm -23 <(echo "$DEFINED_VARS") <(echo "$DOCUMENTED_VARS"))

        if [[ -n "$MISSING_VARS" ]]; then
            MISSING_VARS_FOUND=true
            echo -e "${RED}  ✗ Missing variables in terraform.tfvars.example:${NC}"
            echo "$MISSING_VARS" | while read -r var; do
                echo -e "${RED}    - $var${NC}"
            done
        else
            echo -e "${GREEN}  ✓ All variables documented${NC}"
        fi
    done
done

echo ""
echo "========================================"
if [[ "$MISSING_VARS_FOUND" == true ]]; then
    echo -e "${RED}✗ FAILED: Some variables are missing from terraform.tfvars.example files${NC}"
    echo ""
    echo "Please add the missing variables to the appropriate terraform.tfvars.example file."
    echo "Variables can be commented out if they are optional."
    exit 1
else
    echo -e "${GREEN}✓ PASSED: All variables are documented in terraform.tfvars.example files${NC}"
    exit 0
fi
