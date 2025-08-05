#!/bin/bash
set -euo pipefail

# Prerequisites checks
if ! command -v oc >/dev/null 2>&1; then
  echo "[ERROR] oc CLI is not installed."
  exit 1
fi
if ! command -v sed >/dev/null 2>&1; then
  echo "[ERROR] sed is not installed."
  exit 1
fi

echo "[INFO] Verifying OpenShift login..."
if ! oc whoami &>/dev/null; then
  echo "[ERROR] You are not logged in. Please run 'oc login' first."
  exit 1
fi
echo "[SUCCESS] Logged in as: $(oc whoami)"


# Set Argo CD source Git repo URL
echo "==> Enter the Argo CD application source Git repo URL:"
read -rp "Repo URL: " REPO_URL
sed -i.bak -E "s|(repoURL:[[:space:]]+)[^[:space:]]+|\1${REPO_URL}|" ../cp4d-gitops.yaml
rm -f ../cp4d-gitops.yaml.bak
echo "[SUCCESS] Updated cp4d-gitops.yaml with repoURL: $REPO_URL"


# Commit and push changes to Git 
echo "==> Would you like to commit and push the YAML changes now? (y/n):"
read -r PUSH_NOW
if [[ "$PUSH_NOW" =~ ^[Yy]$ ]]; then
  git add .
  if git diff --cached --quiet; then
    echo "[INFO] No changes to commit."
  else
    git commit -m "Bootstrap script: set repo URL and replaced variables"
    git push
    echo "[SUCCESS] Changes committed and pushed to Git."
  fi
fi


# Apply custom resources
oc apply -f custom-health-checks.yaml
oc apply -f namespaces.yaml
oc apply -f rbac.yaml
echo "[SUCCESS] Namespaces created and ArgoCD configured."


# Create the entitlement secret
echo  "==> Enter the IBM Container Entitlement Key (from https://myibm.ibm.com/products-services/containerlibrary):"
read -srp "Entitlement Key: " ENTITLEMENT_KEY
echo ""
sed "s|\${entitlementKey}|${ENTITLEMENT_KEY}|g" entitlement.tmpl.yaml | oc apply -f -


# Apply the Argo CD Application
echo "[INFO] Applying the Argo CD Application manifest..."
oc apply -f ../cp4d-gitops.yaml -n openshift-gitops
echo "[SUCCESS] Argo CD Application bootstrapped successfully."

echo "[INFO] Retrieving Argo CD dashboard information..."
ARGO_ROUTE=$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')
ARGO_PASS=$(oc get secret openshift-gitops-cluster -n openshift-gitops -o jsonpath="{.data.admin\.password}" | base64 -d 2>/dev/null || true)

if [[ -z "$ARGO_ROUTE" || -z "$ARGO_PASS" ]]; then
  echo "[WARN] Could not retrieve Argo CD dashboard URL or admin password."
else
  echo "=============================================================="
  echo "[INFO] Argo CD Dashboard URL : https://${ARGO_ROUTE}"
  echo "[INFO] Argo CD Admin Password: ${ARGO_PASS}"
  echo "=============================================================="
fi

echo "[SUCCESS] Bootstrap completed."
