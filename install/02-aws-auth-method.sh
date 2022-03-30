#!/bin/bash
export VAULT_KNS="vault"

if [ "$#" -ne 1 ]; then
    echo "Need to enter input parameter ..."
    echo "ROLE_ARN neet to be provided"
    exit 1
else
    test -z "$1" && { echo "Need to provide an AWS Role Arn"; exit 101; } || echo "ROLE_ARN: $1"
fi

# Enable AWS secrets engine
kubectl exec vault-0 -n $VAULT_KNS -- vault secrets enable aws

# The IAM role need to be created before

# Write AWS role will be used from Vault to generate dynamic creds
kubectl exec vault-0 -n $VAULT_KNS -- vault write aws/roles/jenkins-role \
role_arns=$1 credential_type=assumed_role

# Write AWS role will be used from Vault to generate dynamic creds
kubectl exec vault-0 -n $VAULT_KNS -- vault write aws/roles/tekton-role \
role_arns=$1 credential_type=assumed_role

echo -e "Do you want to test the aws secret engine? "
read -s -p "Type [y for proceed | n for stop and exit]: " TEST
case "$TEST" in
    "y")
        kubectl exec vault-0 -n $VAULT_KNS -- vault write aws/sts/jenkins-role ttl=15m
        ;;
    *)
        ;;
esac

exit 0