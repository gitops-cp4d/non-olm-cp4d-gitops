#!/bin/bash
set -euo pipefail

LOG_TAG_WIDTH=9
print_log() {
  printf "[%-${LOG_TAG_WIDTH}s] %s\n" "$1" "$2"
}

# Prerequisites checks
if ! command -v oc >/dev/null 2>&1; then
  print_log "ERROR" "oc CLI is not installed."
  exit 1
fi
if ! command -v sed >/dev/null 2>&1; then
  print_log "ERROR" "sed is not installed."
  exit 1
fi
if ! command -v yq >/dev/null 2>&1; then
  print_log "ERROR" "yq is not installed."
  exit 1
fi
if ! command -v perl >/dev/null 2>&1; then
  print_log "ERROR" "perl is not installed."
  exit 1
fi

# OpenShift login check
print_log "INFO" "Verifying OpenShift login..."
if ! oc whoami &>/dev/null; then
  print_log "ERROR" "You are not logged in. Please run 'oc login' first."
  exit 1
fi
print_log "SUCCESS" "Logged in as: $(oc whoami)"

## Variables replace
print_log "INFO" "Replacing placeholders in YAML files using values.yaml ..."

cd "$(dirname "$0")"
PROJECT_ROOT="$(cd .. && pwd)"
VALUES_FILE="$PROJECT_ROOT/values.yaml"
TMP_KV=".__flattened_kv.tmp"

if [ ! -f "$VALUES_FILE" ]; then
  print_log "ERROR" "Cannot find $VALUES_FILE"
  exit 1
fi

yq eval '.global | to_entries | .[] | select(.value | tag != "!!map") | "\(.key)=\(.value)"' "$VALUES_FILE" > "$TMP_KV"
yq eval '.global | to_entries | .[] | select(.value | tag == "!!map") | . as $root | .value | to_entries | .[] | "\($root.key)-\(.key)=\(.value)"' "$VALUES_FILE" >> "$TMP_KV"

declare -a kvs
while IFS='=' read -r k v; do
  [ -z "$k" ] && continue
  kvs+=("$k=$v")
done < "$TMP_KV"

find "$PROJECT_ROOT" \( -name "*.yaml" -o -name "*.yml" \) | while read -r file; do
  [[ "$file" == "$VALUES_FILE" || "$file" == "$0" ]] && continue
  for kv in "${kvs[@]}"; do
    k="${kv%%=*}"
    v="${kv#*=}"
    perl -pi -e "s|\\\${$k}|$v|g" "$file"
  done
done

rm -f "$TMP_KV"
print_log "SUCCESS" "All parameter placeholders have been replaced."

# Set Argo CD source Git repo URL
echo "==> Enter the Argo CD application source Git repo URL:"
read -rp "Repo URL: " REPO_URL
sed -i.bak -E "s|(repoURL:[[:space:]]+)[^[:space:]]+|\1${REPO_URL}|" ../cp4d-gitops.yaml
rm -f ../cp4d-gitops.yaml.bak
print_log "SUCCESS" "Updated cp4d-gitops.yaml with repoURL: $REPO_URL"

# Commit and push changes to Git 
echo "==> Would you like to commit and push the YAML changes now? (y/n):"
read -r PUSH_NOW
if [[ "$PUSH_NOW" =~ ^[Yy]$ ]]; then
  git add .
  if git diff --cached --quiet; then
    print_log "INFO" "No changes to commit."
  else
    git commit -m "Bootstrap script: set repo URL and replaced variables"
    git push
    print_log "SUCCESS" "Changes committed and pushed to Git."
  fi
fi

# Apply custom resources
oc apply -f custom-health-checks.yaml
oc apply -f namespaces.yaml
oc apply -f rbac.yaml
oc apply -f configmap-namespace-scope.yaml
print_log "SUCCESS" "Namespaces created and ArgoCD configured."

# Create the entitlement secret
echo  "==> Enter the IBM Container Entitlement Key (from https://myibm.ibm.com/products-services/containerlibrary):"
read -srp "Entitlement Key: " ENTITLEMENT_KEY
echo ""

DOCKER_JSON=$(cat <<EOF
{
  "auths": {
    "cp.icr.io": {
      "username": "cp",
      "password": "${ENTITLEMENT_KEY}",
      "email": "cpd@ibm.com",
      "auth": ""
    }
  }
}
EOF
)

DOCKER_JSON_B64=$(echo -n "$DOCKER_JSON" | base64 | tr -d '\n')
export dockerconfigjson_b64=$DOCKER_JSON_B64
sed "s|\${dockerconfigjson_b64}|${DOCKER_JSON_B64}|g" entitlement.tmpl.yaml | oc apply -f -

# Apply the Argo CD Application
print_log "INFO" "Applying the Argo CD Application manifest..."
oc apply -f ../cp4d-gitops.yaml -n openshift-gitops
print_log "SUCCESS" "Argo CD Application bootstrapped successfully."

print_log "INFO" "Retrieving Argo CD dashboard information..."
ARGO_ROUTE=$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')
ARGO_PASS=$(oc get secret openshift-gitops-cluster -n openshift-gitops -o jsonpath="{.data.admin\.password}" | base64 -d 2>/dev/null || true)

if [[ -z "$ARGO_ROUTE" || -z "$ARGO_PASS" ]]; then
  print_log "WARN" "Could not retrieve Argo CD dashboard URL or admin password."
else
  echo "=============================================================="
  print_log "INFO"    "Argo CD Dashboard URL : https://${ARGO_ROUTE}"
  print_log "INFO"    "Argo CD Admin Password: ${ARGO_PASS}"
  echo "=============================================================="
fi

print_log "SUCCESS" "Bootstrap completed."
