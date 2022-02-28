#!/bin/bash
export VAULT_KNS="vault"
export JENKINS_KNS="jenkins"



if ! which kubectl;then
  echo "Kubectl CLI is not installed... "
  exit 1
else
  kubectl cluster-info
  echo -e "\nCheck that this is the right Kubernetes cluster where you want to install.\n "
  echo -e "Using kubernetes context: $(kubectl config current-context)\n"
  read -p "Press any keyboard to continue or Crtl-C to cancel... "
fi

if ! which helm; then
  echo "Helm is not installed and it is required to install Vault and Jenkins... "
  exit 1
fi

install_jenkins () {
  # Installing Jenkins
  helm install jenkins -n $JENKINS_KNS --create-namespace -f jenkins.yaml jenkinsci/jenkins
}

install_tekton () {
  # Installing Tekton
  kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

  # Installing Tekton Dashboard
  kubectl apply --filename https://github.com/tektoncd/dashboard/releases/latest/download/tekton-dashboard-release.yaml
}

kubectl create ns $VAULT_KNS
kubectl create ns $JENKINS_KNS

kubectl apply -f ./config/jenkins-admin-secret.yaml

#kubectl create ns $TKNS

helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo add jenkinsci https://charts.jenkins.io
# Update repos
helm repo update

# Installing Vault in Development mode without the Vault Injector
helm install vault --set injector.enabled=false --set server.dev.enabled=true -n $VAULT_KNS hashicorp/vault



case "$1" in
  "jenkins")
    echo -e "\nInstalling Jenkins...\n"
    install_jenkins 
    ;;
  "tekton")
    echo -e "\nInstalling Tekton Pipelines...\n"
    install_tekton 
    ;;
  "all")
    echo -e "\nInstalling Jenkins and Tekton Pipelines...\n"
    install_jenkins
    install_tekton
    ;;
  *)
    echo -e "\nNo CI/CD to install. Maybe a manual install of your own?... \n"
    ;;
esac
  
