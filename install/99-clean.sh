#!/bin/bash
export VAULT_KNS="vault"
export JENKINS_KNS="jenkins"
export TEKTON_KNS="tekton-pipelines"
export PIPE_KNS="default"


if ! which tkn > /dev/null;then
  echo -e "\nPlease, install Tekton CLI tool...\n"
else
  # Cleaning Tekton objects
  tkn t delete --all -f -n $PIPE_KNS
  tkn tr delete --all -f -n $PIPE_KNS
  tkn p delete --all -f -n $PIPE_KNS
  tkn pr delete --all -f -n $PIPE_KNS
fi 

# Removing configs created
kubectl delete -f ./config

# Uninstalling Vault
helm uninstall vault -n $VAULT_KNS 

# Removing Vault PVCs in the namespace
kubectl delete pvc -n $VAULT_KNS --all

# Uninstalling Jenkins
helm uninstall jenkins -n $JENKINS_KNS 

# Removing Jenkins PVCs in the namespace
kubectl delete pvc -n $JENKINS_KNS --all

# Deleting namespaces
kubectl delete ns  $VAULT_KNS $JENKINS_KNS

