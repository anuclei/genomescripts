#!/bin/bash

# This script performs a series of checks on a Kubernetes cluster to verify the existence and accessibility of certain resources.
# Specifically, it checks the existence of a namespace, a service account, a role, and a role binding.
# It also retrieves and verifies the service account token and CA data, and checks the accessibility of the cluster URL.
# Additionally, it prompts the user to ensure certain Backstage annotations are correctly applied in their catalog-info.yaml file.
# This script is useful for setting up and verifying the Kubernetes environment required for integrating Backstage with Kubernetes.
# Prerequisites:
# - kubectl must be installed and configured to interact with your Kubernetes cluster.
# - curl must be available on your system.

LOG_FILE="check_k8s_backstage.log"

log() {
  local msg="$1"
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $msg" | tee -a $LOG_FILE
}

validate_input() {
  if [ -z "$1" ]; then
    log "Error: Missing input for $2."
    exit 1
  fi
}

# Prompt user for inputs
log "Prompting user for inputs..."
read -p "Enter the namespace: " NAMESPACE
validate_input "$NAMESPACE" "namespace"

read -p "Enter the service account name: " SERVICE_ACCOUNT_NAME
validate_input "$SERVICE_ACCOUNT_NAME" "service account name"

read -p "Enter the role name: " ROLE_NAME
validate_input "$ROLE_NAME" "role name"

read -p "Enter the role binding name: " ROLE_BINDING_NAME
validate_input "$ROLE_BINDING_NAME" "role binding name"

read -p "Enter the cluster URL: " CLUSTER_URL
validate_input "$CLUSTER_URL" "cluster URL"

read -p "Enter the cluster name: " CLUSTER_NAME
validate_input "$CLUSTER_NAME" "cluster name"

read -p "Enter the Backstage Kubernetes ID: " BACKSTAGE_K8S_ID
validate_input "$BACKSTAGE_K8S_ID" "Backstage Kubernetes ID"

read -p "Enter the Backstage label selector: " BACKSTAGE_LABEL_SELECTOR
validate_input "$BACKSTAGE_LABEL_SELECTOR" "Backstage label selector"

log "Checking namespace..."
if kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
  log "Namespace $NAMESPACE exists."
else
  log "Namespace $NAMESPACE does not exist."
fi

log "Checking service account..."
if kubectl get serviceaccount $SERVICE_ACCOUNT_NAME --namespace $NAMESPACE >/dev/null 2>&1; then
  log "Service account $SERVICE_ACCOUNT_NAME exists in namespace $NAMESPACE."
else
  log "Service account $SERVICE_ACCOUNT_NAME does not exist in namespace $NAMESPACE."
fi

log "Checking role..."
if kubectl get role $ROLE_NAME --namespace $NAMESPACE >/dev/null 2>&1; then
  log "Role $ROLE_NAME exists in namespace $NAMESPACE."
else
  log "Role $ROLE_NAME does not exist in namespace $NAMESPACE."
fi

log "Checking role binding..."
if kubectl get rolebinding $ROLE_BINDING_NAME --namespace $NAMESPACE >/dev/null 2>&1; then
  log "Role binding $ROLE_BINDING_NAME exists in namespace $NAMESPACE."
else
  log "Role binding $ROLE_BINDING_NAME does not exist in namespace $NAMESPACE."
fi

log "Checking service account token..."
SECRET_NAME=$(kubectl get serviceaccount $SERVICE_ACCOUNT_NAME --namespace $NAMESPACE -o jsonpath='{.secrets[0].name}' 2>/dev/null)
if [ -n "$SECRET_NAME" ]; then
  log "Secret $SECRET_NAME associated with service account $SERVICE_ACCOUNT_NAME found."
  TOKEN=$(kubectl get secret $SECRET_NAME --namespace $NAMESPACE -o jsonpath='{.data.token}' 2>/dev/null | base64 --decode)
  if [ -n "$TOKEN" ]; then
    MASKED_TOKEN="${TOKEN:0:4}...${TOKEN: -4}"
    log "Service account token retrieved successfully: $MASKED_TOKEN"
  else
    log "Failed to retrieve service account token."
  fi
  CA_DATA=$(kubectl get secret $SECRET_NAME --namespace $NAMESPACE -o jsonpath='{.data.ca\.crt}' 2>/dev/null | base64 --decode)
  if [ -n "$CA_DATA" ]; then
    MASKED_CA_DATA="${CA_DATA:0:4}...${CA_DATA: -4}"
    log "CA data retrieved successfully: $MASKED_CA_DATA"
  else
    log "Failed to retrieve CA data."
  fi
else
  log "No secret associated with service account $SERVICE_ACCOUNT_NAME found."
fi

log "Checking cluster URL accessibility..."
if curl --insecure -s $CLUSTER_URL >/dev/null; then
  log "Cluster URL $CLUSTER_URL is accessible."
else
  log "Cluster URL $CLUSTER_URL is not accessible."
fi

log "Checking Backstage catalog-info.yaml annotations..."
log "Ensure the following annotations are correctly applied in your catalog-info.yaml:"
log "  annotations:"
log "    backstage.io/kubernetes-id: $BACKSTAGE_K8S_ID"
log "    backstage.io/kubernetes-namespace: $NAMESPACE"
log "    backstage.io/kubernetes-label-selector: \"$BACKSTAGE_LABEL_SELECTOR\""

log "Checking Kubernetes resources with label selector..."
if kubectl get pods -n $NAMESPACE -l app=$BACKSTAGE_LABEL_SELECTOR >/dev/null 2>&1; then
  log "Pods with label app=$BACKSTAGE_LABEL_SELECTOR found in namespace $NAMESPACE."
else
  log "No pods with label app=$BACKSTAGE_LABEL_SELECTOR found in namespace $NAMESPACE."
fi

log "Summary of checks:"
kubectl get namespace $NAMESPACE >/dev/null 2>&1 || log "- Namespace $NAMESPACE does not exist."
kubectl get serviceaccount $SERVICE_ACCOUNT_NAME --namespace $NAMESPACE >/dev/null 2>&1 || log "- Service account $SERVICE_ACCOUNT_NAME does not exist in namespace $NAMESPACE."
kubectl get role $ROLE_NAME --namespace $NAMESPACE >/dev/null 2>&1 || log "- Role $ROLE_NAME does not exist in namespace $NAMESPACE."
kubectl get rolebinding $ROLE_BINDING_NAME --namespace $NAMESPACE >/dev/null 2>&1 || log "- Role binding $ROLE_BINDING_NAME does not exist in namespace $NAMESPACE."
[ -n "$SECRET_NAME" ] || log "- No secret associated with service account $SERVICE_ACCOUNT_NAME found."
[ -n "$TOKEN" ] || log "- Failed to retrieve service account token."
[ -n "$CA_DATA" ] || log "- Failed to retrieve CA data."
curl --insecure -s $CLUSTER_URL >/dev/null || log "- Cluster URL $CLUSTER_URL is not accessible."
kubectl get pods -n $NAMESPACE -l app=$BACKSTAGE_LABEL_SELECTOR >/dev/null 2>&1 || log "- No pods with label app=$BACKSTAGE_LABEL_SELECTOR found in namespace $NAMESPACE."

log "Please address any issues identified above and re-run the script to verify the configuration."
log "Script execution complete. Logs have been saved to $LOG_FILE."

exit 0
