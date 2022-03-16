#!/bin/bash

VAULT_TERRAFORM_PATH=$1
WORKSPACE=$2
# Replace . with - because . isn't allowed as tag name
WS_TAG=$(echo $2 | tr . -)
VAR_TAG=$3
VAR_COMMIT=$4

curl -L https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -o ./jq-linux64 && chmod 755 ./jq-linux64
export TFE_TOKEN="$(curl -H "X-Vault-Token: ${VAULT_TOKEN}" -X GET ${VAULT_ADDR}/v1/$VAULT_TERRAFORM_PATH | ./jq-linux64 -r .data.token)"

WORKSPACE_VARS=$(curl -H "Authorization: Bearer $TFE_TOKEN" -H "Content-Type: application/vnd.api+json" -X GET "https://app.terraform.io/api/v2/workspaces/${WORKSPACE}/vars" | ./jq-linux64 -r)

# Variables needs to be created before (typically by tfe provider that takes care about terraforming terraform)
echo $WORKSPACE_VARS | ./jq-linux64 -r '.data[] | .id + "," + .attributes.key + "," + .attributes.category' | while read VARIABLE
do
  VAR_ID=$(awk -F, '{print $1}' <<< "$VARIABLE")
  VAR_TYPE=$(awk -F, '{print $3}' <<< "$VARIABLE")
  VAR_NAME=$(awk -F, '{print $2}' <<< "$VARIABLE")

  case "$VAR_NAME" in
    git-tag)
      # update value of a git-tag variable with the latest tag
      echo '{"data": {"id":"'${VAR_ID}'","attributes": {"key":"'${VAR_NAME}'","value":"'${VAR_TAG}'","category":"'${VAR_TYPE}'","hcl": false,"sensitive": false},"type":"vars"} }' > payload.json
      curl -H "Authorization: Bearer $TFE_TOKEN" -H "Content-Type: application/vnd.api+json" -X PATCH -d @payload.json "https://app.terraform.io/api/v2/workspaces/${WORKSPACE}/vars/${VAR_ID}"
      rm payload.json
    ;;
    git-commit)
      # update value of a git-commit with the latest commit
      echo 'data": {"id":"'${VAR_ID}'","attributes": {"key":"'${VAR_NAME}'","value":"'${VAR_COMMIT}'","category":"'${VAR_TYPE}'","hcl": false,"sensitive": false},"type":"vars"} }' > payload.json
      curl -H "Authorization: Bearer $TFE_TOKEN" -H "Content-Type: application/vnd.api+json" -X PATCH -d @payload.json "https://app.terraform.io/api/v2/workspaces/${WORKSPACE}/vars/${VAR_ID}"
      rm payload.json
    ;;
    *)
    ;;
  esac
done


# Create an organization tag and link to the workspace
cat - <<EOF > payload.json
{ "data": [ { "type": "tags", "attributes": { "name": "${TAG}" } } ] }
EOF

echo '{ "data": [ { "type": "tags", "attributes": { "name": "${TAG}" } } ] }'

curl \
  --header "Authorization: Bearer $TFE_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @payload.json \
  https://app.terraform.io/api/v2/workspaces/${WORKSPACE}/relationships/tags