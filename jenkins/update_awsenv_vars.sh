#!/bin/env bash

# ./updatevars.sh <vault_secret_path> <tfc_workspace>

VAULT_TERRAFORM_PATH=$1
VAULT_AWS_PATH=$2
TTL_AWS_CREDS=$3
WORKSPACE=$4

echo "VAULT_TERRAFORM_PATH: $VAULT_TERRAFORM_PATH"
echo "VAULT_AWS_PATH: $VAULT_AWS_PATH"
echo "TTL_AWS_CREDS: $TTL_AWS_CREDS"
echo "WORKSPACE: $WORKSPACE"


echo "===========> Get TFE_TOKEN"
curl -L https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -o ./jq-linux64 && chmod 755 ./jq-linux64
export TFE_TOKEN="$(curl -H "X-Vault-Token: ${VAULT_TOKEN}" -X GET ${VAULT_ADDR}/v1/$VAULT_TERRAFORM_PATH | ./jq-linux64 -r .data.token)"

echo "===========> Get Credentials"
# Let's generate new aws dynamic credentials
curl -H "X-Vault-Token: ${VAULT_TOKEN}" -X POST -d '{"ttl": "'${TTL_AWS_CREDS}'"}' ${VAULT_ADDR}/v1/${VAULT_AWS_PATH} | ./jq-linux64 -r ".data" > aws-creds-tmp.json

# Let's put the keys in a file
AWS_ACCESS_KEY_ID_VALUE=$(./jq-linux64 -r '.access_key' aws-creds-tmp.json)
AWS_SECRET_ACCESS_KEY_VALUE=$(./jq-linux64 -r '.secret_key' aws-creds-tmp.json)
AWS_SESSION_TOKEN_VALUE=$(./jq-linux64 -r '.security_token' aws-creds-tmp.json)

rm aws-creds-tmp.json

cat aws-creds-tmp.json

echo "===========> Get Workspace variable"
# Check if env variable exists
WORKSPACE_VARS=$(curl -H "Authorization: Bearer $TFE_TOKEN" -H "Content-Type: application/vnd.api+json" -X GET "https://app.terraform.io/api/v2/workspaces/${WORKSPACE}/vars" | ./jq-linux64 -r)

echo $WORKSPACE_VARS | ./jq-linux64 -r '.data[] | .id + "," + .attributes.key + "," + .attributes.category' | while read VARIABLE
do
  VAR_ID=$(awk -F, '{print $1}' <<< "$VARIABLE")
  VAR_TYPE=$(awk -F, '{print $3}' <<< "$VARIABLE")
  VAR_NAME=$(awk -F, '{print $2}' <<< "$VARIABLE")

  case "$VAR_NAME" in
    AWS_ACCESS_KEY_ID)
      echo "VAR_NAME: ${VAR_NAME}"
      echo '{"data": {"id":"'${VAR_ID}'","attributes": {"key":"'${VAR_NAME}'","value":"'${AWS_ACCESS_KEY_ID_VALUE}'","category":"'${VAR_TYPE}'","hcl": false,"sensitive": false},"type":"vars"} }' > payload.json
      curl -H "Authorization: Bearer $TFE_TOKEN" -H "Content-Type: application/vnd.api+json" -X PATCH -d @payload.json "https://app.terraform.io/api/v2/workspaces/${WORKSPACE}/vars/${VAR_ID}"
      rm payload.json
      ;;
    AWS_SECRET_ACCESS_KEY)
      echo "VAR_NAME: ${VAR_NAME}"
      echo '{"data": {"id":"'${VAR_ID}'","attributes": {"key":"'${VAR_NAME}'","value":"'${AWS_SECRET_ACCESS_KEY_VALUE}'","category":"'${VAR_TYPE}'","hcl": false,"sensitive": true},"type":"vars"} }' > payload.json
      curl -H "Authorization: Bearer $TFE_TOKEN" -H "Content-Type: application/vnd.api+json" -X PATCH -d @payload.json "https://app.terraform.io/api/v2/workspaces/${WORKSPACE}/vars/${VAR_ID}"
      rm payload.json
      ;;
    AWS_SESSION_TOKEN)
      echo "VAR_NAME: ${VAR_NAME}"
      echo '{"data": {"id":"'${VAR_ID}'","attributes": {"key":"'${VAR_NAME}'","value":"'${AWS_SESSION_TOKEN_VALUE}'","category":"'${VAR_TYPE}'","hcl": false,"sensitive": true},"type":"vars"} }' > payload.json
      curl -H "Authorization: Bearer $TFE_TOKEN" -H "Content-Type: application/vnd.api+json" -X PATCH -d @payload.json "https://app.terraform.io/api/v2/workspaces/${WORKSPACE}/vars/${VAR_ID}"
      rm payload.json
      ;;
    AWS_SESSION_EXPIRATION)
      echo "VAR_NAME: ${VAR_NAME}"
      EXP_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
      echo "EXP_DATE: ${EXP_DATE}"
      #echo '{"data": {"id":"'${VAR_ID}'","attributes": {"key":"'${VAR_NAME}'","value":"'${EXP_DATE}'","category":"'${VAR_TYPE}'","hcl": false,"sensitive": false},"type":"vars"} }' > payload.json
      #curl -H "Authorization: Bearer $TFE_TOKEN" -H "Content-Type: application/vnd.api+json" -X PATCH -d @payload.json "https://app.terraform.io/api/v2/workspaces/${WORKSPACE}/vars/${VAR_ID}"
      #rm payload.json
      ;;
    *)
      echo "variable ${VAR_NAME} will be skipped"
      ;;
  esac

done
