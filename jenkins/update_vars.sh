#!/bin/env bash

VAULT_VALUES_PATH=$1
VAULT_TERRAFORM_PATH=$2
WORKSPACE=$3

echo "VAULT_VALUES_PATH: $VAULT_VALUES_PATH"
echo "VAULT_TERRAFORM_PATH: $VAULT_TERRAFORM_PATH"
echo "WORKSPACE: $WORKSPACE"

curl -L https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -o ./jq-linux64 && chmod 755 ./jq-linux64
echo "===========> Get TFE_TOKEN"
export TFE_TOKEN="$(curl -H "X-Vault-Token: ${VAULT_TOKEN}" -X GET ${VAULT_ADDR}/v1/$VAULT_TERRAFORM_PATH | ./jq-linux64 -r .data.token)"

echo "===========> Get workspace variables"
# Get workspace variables
WORKSPACE_VARS=$(curl -H "Authorization: Bearer $TFE_TOKEN" -H "Content-Type: application/vnd.api+json" -X GET "https://app.terraform.io/api/v2/workspaces/${WORKSPACE}/vars" | ./jq-linux64 -r)
echo $WORKSPACE_VARS

echo "===========> Get the vars key/value to change from Vault"
# Let's get the vars keys to change from Vault
curl -H "X-Vault-Token: ${VAULT_TOKEN}" -X GET ${VAULT_ADDR}/v1/${VAULT_VALUES_PATH} | ./jq-linux64 -r ".data.data" > tfevalues.json
cat tfevalues.json

# Let's put the keys in a file
./jq-linux64 -r 'keys | .[]' tfevalues.json > tfekeys.txt
cat tfekeys.txt

echo $WORKSPACE_VARS | ./jq-linux64 -r '.data[] | .id + "," + .attributes.key + "," + .attributes.category' | while read VARIABLE
do
  VAR_ID=$(awk -F, '{print $1}' <<< "$VARIABLE")
  VAR_TYPE=$(awk -F, '{print $3}' <<< "$VARIABLE")
  VAR_NAME=$(awk -F, '{print $2}' <<< "$VARIABLE")
  echo "$VAR_ID - $VAR_TYPE - $VAR_NAME"

  CHECK_IF_VAR_EXISTS=$(grep -R ${VAR_NAME} tfekeys.txt)

  if [[ ! -z "$CHECK_IF_VAR_EXISTS" ]]
  then
    if [ "$VAR_NAME" == "jenkins-timestamp" ]; then
      JENKINS_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
      echo "=======> jenkins-timestamp: ${JENKINS_TIMESTAMP}"
      echo '{"data": {"attributes": {"key": "'${VAR_NAME}'","value": "'${JENKINS_TIMESTAMP}'","hcl": false, "sensitive": false},"type":"vars","id":"'${VAR_ID}'"}}' > varpayload.json
      curl -H "Authorization: Bearer $TFE_TOKEN" -H "Content-Type: application/vnd.api+json" -X PATCH -d @varpayload.json "https://app.terraform.io/api/v2/workspaces/${WORKSPACE}/vars/${VAR_ID}"
    else 
      VAR_VALUE=$(./jq-linux64 --arg v "$VAR_NAME" -r '.[$v]' tfevalues.json)
      echo $VAR_VALUE
      echo '{"data": {"attributes": {"key": "'${VAR_NAME}'","value": "'${VAR_VALUE}'","hcl": false, "sensitive": false},"type":"vars","id":"'${VAR_ID}'"}}' > varpayload.json
      curl -H "Authorization: Bearer $TFE_TOKEN" -H "Content-Type: application/vnd.api+json" -X PATCH -d @varpayload.json "https://app.terraform.io/api/v2/workspaces/${WORKSPACE}/vars/${VAR_ID}"
      rm varpayload.json
    fi
  fi

done
