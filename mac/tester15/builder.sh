#!/bin/bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Define default values
DEFAULT_VM_NAME="sequoia-tester"
DEFAULT_VAULT_FILE="vault-fake.yaml"  # Fallback for local dev

# Allow environment variables to override
VM_NAME="${VM_NAME:-$DEFAULT_VM_NAME}"
VAULT_FILE="${VAULT_FILE:-$DEFAULT_VAULT_FILE}"

# Ensure vault file exists
if [[ ! -f "$VAULT_FILE" ]]; then
    echo "❌ Vault file not found at '$VAULT_FILE'"
    echo ""
    echo "Current directory: $(pwd)"
    echo "VAULT_FILE env var: ${VAULT_FILE:-<not set>}"
    echo ""
    
    # Only prompt if running interactively (not in CI)
    if [[ -t 0 ]]; then
        read -r -p "🔑 Enter the path to the Vault file: " VAULT_FILE
        if [[ ! -f "$VAULT_FILE" ]]; then
            echo "❌ File still not found. Exiting."
            exit 1
        fi
    else
        echo "Running in non-interactive mode (CI). Cannot prompt for input."
        exit 1
    fi
fi

# Confirm settings before running
echo "⚡ Starting macOS CI Image Build..."
echo "  - VM Name: $VM_NAME"
echo "  - Vault File: $VAULT_FILE"
echo ""

# Run the packer builds
# Phase 1: Create base (no vm_name variable in this file)
packer build -force create-base.pkr.hcl

# Phase 2: Disable SIP (uses vm_name)
packer build -force \
  -var="vm_name=$VM_NAME" \
  disable-sip.pkr.hcl

# Phase 3: Puppet setup phase 1 (uses vm_name and vault_file)
packer build -force \
  -var="vm_name=$VM_NAME" \
  -var="vault_file=$VAULT_FILE" \
  puppet-setup-phase1.pkr.hcl

# Phase 4: Puppet setup phase 2 (uses vm_name and vault_file)
packer build -force \
  -var="vm_name=$VM_NAME" \
  puppet-setup-phase2.pkr.hcl
  -var="vault_file=$VAULT_FILE" \
  puppet-setup-phase2.pkr.hcl

echo "✅ Build process completed successfully!"