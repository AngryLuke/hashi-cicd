#!/bin/bash
export VAULT_KNS="vault"
export TKNS="tektoncd"

if [ "$#" -ne 4 ]; then
    echo "Need to enter 4 input parameters"
    echo "<TFE_ORG> <TFE_USER> <SECRETS_FILE> <TFE_FILE>"
    exit 1
else
    test -z "$1" && { echo "Need to provide a Terraform Org name"; exit 101; } || echo "TFE_ORG: $1"
    test -z "$2" && { echo "Need to provide a Terraform User name"; exit 102; } || echo "TFE_USER: $2"
    test ! -f "$3" && { echo "Need to provide an existing secrets json file"; exit 103; } || echo "SECRETSFILE: $3"
    test ! -f "$4" && { echo "Need to provide an existing tfe values json file"; exit 104; } || echo "TFEVALUESFILE: $4"
fi

if [ -f "$HOME/.terraform.d/credentials.tfrc.json" ];then
    export TOKEN="$(cat $HOME/.terraform.d/credentials.tfrc.json | jq ".credentials.\"app.terraform.io\".token" | tr -d '"')"
else
    echo -e "\nTerraform credentials not found. Consider doing \"terraform login\" next time...\n"
    read -s -p "Insert your Terraform Cloud user API Token: " TOKEN
fi

if ! which jq > /dev/null;then
    echo -e "\nThis script needs \"jq\" to parse JSON outputs. Please, install \"jq\"..."
    exit 10
fi

if [ -z "$1" ] || [ -z "$2" ];then
    echo -e "\nPlease type your Terraform Cloud Org and Terraform Cloud user as parameters: \n"
    echo -e "\t $0 <YOUR_TFC_ORG> <YOUR_TFC_USERNAME> \n"
    exit 20
fi

export TEAMID="$(curl \
-H "Authorization: Bearer $TOKEN" \
-H "Content-Type: application/vnd.api+json" \
https://app.terraform.io/api/v2/organizations/$1/teams \
| jq -r '.data[] | select(.attributes.name == "owners") | .id')"

export TFUSERID="$(curl \
-H "Authorization: Bearer $TOKEN" \
-H "Content-Type: application/vnd.api+json" \
"https://app.terraform.io/api/v2/teams/$TEAMID?include=users" \
| jq -r  ".included[] | select(.attributes.username == \"$2\") | .id")"

echo -e "\nTerraform Cloud Team ID for Owners at organization $1: $TEAMID"
echo -e "\nTerraform Cloud User ID for user $2: $TFUSERID\n"

# Deploy Vault SA for JWT Token Review, Tekton pipelines service account and Vault Agent ConfigMap
kubectl apply -f ./config/jenkins-admin-secret.yaml

#kubectl create sa tekton -n $TKNS

# Configuring Vault
export VAULT_SA_NAME="$(kubectl get sa vault -n $VAULT_KNS \
    --output go-template='{{ range .secrets }}{{ .name }}{{ end }}')"

export SA_JWT_TOKEN="$(kubectl get secret $VAULT_SA_NAME -n $VAULT_KNS \
    --output 'go-template={{ .data.token }}' | base64 --decode)"

export SA_CA_CRT=$(kubectl get secret $VAULT_SA_NAME -n $VAULT_KNS \
    -o go-template='{{ index .data "ca.crt" }}' | base64 -d; echo)

export K8S_HOST="$(kubectl exec -ti vault-0 -n vault -- printenv KUBERNETES_SERVICE_HOST | tr -d '\r')"
export K8S_PORT=$(kubectl exec -ti vault-0 -n vault -- printenv KUBERNETES_SERVICE_PORT | tr -d '\r')

# Write policy to be used from jenkins
# This command need to be refactored
kubectl exec -i vault-0 -n $VAULT_KNS -- vault policy write jenkins - <<EOF
path "kv/data/cicd/*" { 
  capabilities = ["read", "update", "list"] 
}
path "kv/cicd/*" { 
  capabilities = ["read", "update", "list"] 
}
path "kv/cicd" { 
  capabilities = ["read", "update", "list"] 
}
path "kv/data/cicd" { 
  capabilities = ["read", "update", "list"] 
}
path "kv/data/tfevalues" { 
  capabilities = ["read", "update", "list"] 
}
path "terraform/creds/tfe-role" { 
  capabilities = ["read", "update", "list"] 
}
path "aws/sts/jenkins-role" {
    capabilities = ["read", "create", "list", "update"]
}
path "aws/sts/tekton-role" {
    capabilities = ["read", "create", "list", "update"]
}
path "auth/token/create" {
    capabilities = ["update"]
}
EOF

# Write policy to be used from tekton
kubectl exec -i vault-0 -n $VAULT_KNS -- vault policy write tektonpol - <<EOF
path "secret/data/cicd/*" {
    capabilities = ["read","update","list"]
}
path "terraform/creds/*" {
    capabilities = ["read","list"]
}
EOF

# Enable the K8s auth method at the kubernetes/ path
kubectl exec vault-0 -n $VAULT_KNS -- vault auth enable kubernetes

# Configure the K8s auth method for use JWT ServiceAccount
kubectl exec vault-0 -n $VAULT_KNS -- vault write auth/kubernetes/config \
  token_reviewer_jwt="$SA_JWT_TOKEN" \
  kubernetes_host="https://$K8S_HOST:$K8S_PORT" \
  kubernetes_ca_cert="$SA_CA_CRT"
  #issuer="https://kubernetes.default.svc.cluster.local"

kubectl exec vault-0 -n $VAULT_KNS -- vault write auth/kubernetes/role/jenkins \
  bound_service_account_names="jenkins","default"\
  bound_service_account_namespaces="jenkins","default" \
  policies="jenkins" \
  token_no_default_policy=false \
  token_ttl="1m"

kubectl exec vault-0 -n $VAULT_KNS -- vault write auth/kubernetes/role/tekton \
  bound_service_account_names="tekton-sa","default"\
  bound_service_account_namespaces="tekton-pipelines","default" \
  policies="tektonpol" \
  token_no_default_policy=false \
  token_ttl="1m"

# Enable the Terraform Cloud secrets engine at the terraform/ path
kubectl exec vault-0 -n $VAULT_KNS -- vault secrets enable terraform
# Configure the Terraform Cloud secrets engine to use the TF_TOKEN token
kubectl exec vault-0 -n $VAULT_KNS -- vault write terraform/config token="$TOKEN"
# Create a role named tfe-role with the USER_ID and a time-to-live of 10 minutes.
kubectl exec vault-0 -n $VAULT_KNS -- vault write terraform/role/tfe-role user_id=$TFUSERID ttl=10m

# Enable the kv secrets engine at the kv/ path
kubectl exec vault-0 -n $VAULT_KNS -- vault secrets enable -version 2 kv

# Put static secrets starting from kv/ mount point
cat $3 | kubectl exec vault-0 -n $VAULT_KNS -ti -- vault kv put kv/cicd -
cat $4 | kubectl exec vault-0 -n $VAULT_KNS -ti -- vault kv put kv/tfevalues -

exit 0