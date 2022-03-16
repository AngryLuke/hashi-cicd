#!/bin/env bash

VAULT_VALUES_PATH=$1
VAULT_TERRAFORM_PATH=$2
WORKSPACE=$3


curl -L https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -o ./jq-linux64 && chmod 755 ./jq-linux64
export TFE_TOKEN="$(curl -H "X-Vault-Token: ${VAULT_TOKEN}" -X GET ${VAULT_ADDR}/v1/$VAULT_TERRAFORM_PATH | ./jq-linux64 -r .data.token)"

# Getting the vars from the workspace
# curl -H "Authorization: Bearer $TFE_TOKEN" -H "Content-Type: application/vnd.api+json" -X GET "https://app.terraform.io/api/v2/workspaces/${WORKSPACE}/vars" > wvars.json

# Get workspace variables
WORKSPACE_VARS=$(curl -H "Authorization: Bearer $TFE_TOKEN" -H "Content-Type: application/vnd.api+json" -X GET "https://app.terraform.io/api/v2/workspaces/${WORKSPACE}/vars" | ./jq-linux64 -r)

# Let's get the vars keys to change from Vault
curl -H "X-Vault-Token: ${VAULT_TOKEN}" -X GET ${VAULT_ADDR}/v1/${VAULT_VALUES_PATH} | ./jq-linux64 -r ".data.data" > tfevalues.json
cat tfevalues.json

# Let's put the keys in a file
./jq-linux64 -r 'keys | .[]' tfevalues.json > tfekeys.txt
cat tfekeys.txt

echo $WORKSPACE_VARS

echo $WORKSPACE_VARS | ./jq-linux64 -r '.data[] | .id + "," + .attributes.key + "," + .attributes.category' | while read VARIABLE
do
  VAR_ID=$(awk -F, '{print $1}' <<< "$VARIABLE")
  VAR_TYPE=$(awk -F, '{print $3}' <<< "$VARIABLE")
  VAR_NAME=$(awk -F, '{print $2}' <<< "$VARIABLE")
  echo "$VAR_ID - $VAR_TYPE - $VAR_NAME"

  CHECK_IF_VAR_EXISTS=$(grep -R ${VAR_NAME} tfekeys.txt)

  echo $CHECK_IF_VAR_EXISTS

  if [[ ! -z "$CHECK_IF_VAR_EXISTS" ]]
  then
    VAR_VALUE=$(./jq-linux64 --arg v "$VAR_NAME" -r '.[$v]' tfevaules.json)
    echo $VAR_VALUE
    echo "{"data": {"attributes": {"key": "${VAR_NAME}","value": "${VAR_VALUE}","hcl": false, "sensitive": false},"type":"vars","id":"${VAR_ID}"}}" > varpayload.json
    cat varpayload.json
    curl -H "Authorization: Bearer $TFE_TOKEN" -H "Content-Type: application/vnd.api+json" -X PATCH -d @varpayload.json "https://app.terraform.io/api/v2/workspaces/${WORKSPACE}/vars/${VARID}"
    rm varpayload.json
  fi

done
