#!/usr/bin/env bash
# assign-storage-rbac.sh
# Purpose: Grant a Service Principal (App registration) the 'Storage Blob Data Contributor' role
#          scoped to a specific Storage Account for Terraform remote state (or other blob ops).
#
# Usage:
#   Export or supply required environment variables before running:
#     SUBSCRIPTION_ID, RESOURCE_GROUP, STORAGE_ACCOUNT, SP_APP_ID
#
#   Example:
#     export SUBSCRIPTION_ID="7060853a-10fc-46c8-b90c-5bfe6e92e62f"
#     export RESOURCE_GROUP="rg-taxifares-0001dev-tf"
#     export STORAGE_ACCOUNT="sttaxifares0001devtf"
#     export SP_APP_ID="2d3fb311-ebca-40c7-a13d-096b8143c613"
#     az login --service-principal -u "$SP_APP_ID" -p "$CLIENT_SECRET" --tenant "922fd3f2-2199-4d31-b069-9733c4a14c63"
#       # OR use 'az login' with your user account that has Owner role
#     ./scripts/assign-storage-rbac.sh
#
# Notes:
#   - This script does NOT accept or use the client secret directly; authentication must occur *before* execution.
#   - Requires that the logged-in principal has permission to create role assignments at target scope (Owner or User Access Administrator).
#   - Safe to re-run; it will detect existing assignment and skip.
#   - Does not store secrets in the repository.
#
# Exit codes:
#   0 success (role already present or newly assigned)
#   1 missing required environment variable
#   2 assignment attempt failed
#
set -euo pipefail

REQUIRED_VARS=(SUBSCRIPTION_ID RESOURCE_GROUP STORAGE_ACCOUNT SP_APP_ID)
for v in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!v:-}" ]]; then
    echo "[ERROR] Required environment variable $v is not set." >&2
    exit 1
  fi
done

SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Storage/storageAccounts/${STORAGE_ACCOUNT}"
ROLE_NAME="Storage Blob Data Contributor"

echo "[INFO] Checking existing role assignments for SP $SP_APP_ID at scope $SCOPE ..."
EXISTING=$(az role assignment list --assignee "${SP_APP_ID}" --scope "${SCOPE}" --query "[?roleDefinitionName=='${ROLE_NAME}'].id" -o tsv || true)
if [[ -n "${EXISTING}" ]]; then
  echo "[INFO] Role '${ROLE_NAME}' already assigned (id: ${EXISTING}). Skipping.";
  exit 0
fi

echo "[INFO] Assigning role '${ROLE_NAME}' to SP ${SP_APP_ID} at scope ${SCOPE} ..."
if az role assignment create --role "${ROLE_NAME}" --assignee "${SP_APP_ID}" --scope "${SCOPE}" -o jsonc >/dev/null; then
  echo "[SUCCESS] Role '${ROLE_NAME}' assigned successfully. Propagation may take a few minutes.";
  exit 0
else
  echo "[ERROR] Failed to assign role '${ROLE_NAME}'." >&2
  exit 2
fi
