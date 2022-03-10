#!/bin/env bash

# ./updatevars.sh <vault_secret_path> <tfc_workspace>

VAULT_VALUES_PATH=$1
VAULT_TERRAFORM_PATH=$2
WORKSPACE=$3


curl -L https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -o ./jq-linux64 && chmod 755 ./jq-linux64
export TFE_TOKEN="$(curl -H "X-Vault-Token: ${VAULT_TOKEN}" -X GET ${VAULT_ADDR}/v1/$VAULT_TERRAFORM_PATH | ./jq-linux64 -r .data.token)"

# Getting the vars from the workspace
curl -H "Authorization: Bearer $TFE_TOKEN" -H "Content-Type: application/vnd.api+json" -X GET "https://app.terraform.io/api/v2/workspaces/${WORKSPACE}/vars" > wvars.json

# Let's get the vars keys to change from Vault
curl -H "X-Vault-Token: ${VAULT_TOKEN}" -X GET ${VAULT_ADDR}/v1/${VAULT_VALUES_PATH} | ./jq-linux64 -r ".data.data" > tfevalues.json
cat tfevalues.json

# Let's put the keys in a file
./jq-linux64 -r 'keys | .[]' tfevalues.json > tfekeys.txt
cat tfekeys.txt

# Let's iterate the variable keys to get the var ids and change the value in TFE
while read -r line;do
  export VARID="$(./jq-linux64 -r ".data[] | select(.attributes.key == \"$line\") | .id" wvars.json)"
  export VARVALUE="$(./jq-linux64 -r ".\"$line\"" tfevalues.json)"
  echo "This is the var ID: $VARID"
  cat - <<EOF > varpayload.json
{"data": {"attributes": {"key": "${line}","value": "${VARVALUE}","hcl": false, "sensitive": false},"type":"vars","id":"${VARID}"}}
EOF
  ./jq-linux64 -r . varpayload.json
  curl -H "Authorization: Bearer $TFE_TOKEN" -H "Content-Type: application/vnd.api+json" -X PATCH -d @varpayload.json "https://app.terraform.io/api/v2/workspaces/${WORKSPACE}/vars/${VARID}"
done < tfekeys.txt 