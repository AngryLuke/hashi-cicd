# CI/CD Pipelines Vault Integration

Example of Vault integration with CI/CD pipelines

## Requirements

* Running K8s cluster
* `kubectl` CLI installed
* Helm CLI installed
* A Terraform Cloud user and organization (some of the example pipelines do a TFC run)


## Installation

Install Vault and Jenkins:
```bahs
cd install
make jenkins
```

The script is going to ask if you are using the righ K8s context. Press any key to continue or Crtl'C to cancel.

> NOTE:
> *If you want to install every included CI/CD engine (Tekton Pipelines by now):*
> ```bash
> make install
> ```

Use the static secrets file as a template `install/config/secrets.json` to create your own and apply your custom values:
```json
{
  "<tfc_var1>": "<value_to_be_set>",
  "<tfc_var2>": "<value_to_be_set>",
  "..." : "...",
  "<tfc_varn>": "<value_to_be_set>",
  "tfe_org": "<your_tfc_org>",
  "tfe_token": "<static_example_tfe_token>",
  "gh_user": "<gh_token>",
  "gh_token": "<gh_token> "
}
```

For example you can copy that file in another folder and write your personal secrets: this new file will be the one you'll
use in the next step.
> ```bash
> cp install/config/secrets.json <your_preferred_path>/<your_secrets_file>.json
> ```

```json
{
  "<tfc_var1>": "<value_to_be_set>",
  "<tfc_var2>": "<value_to_be_set>",
  "..." : "...",
  "<tfc_varn>": "<value_to_be_set>"
}
```

`<tfc_var1> ... <tfc_varn>` are **existing variable keys in your Terraform Cloud Workspace**
Also, configure the values of another secret with only the Terraform Cloud variables of your workspace. That is in the file `install/config/tfe_values.json`:


`<tfc_var1> ... <tfc_varn>` are **existing variable keys in your Terraform Cloud Workspace**. It they are not existing in the Workspace pipelines will fail.



Configure Vault with the required secrets and Kubernetes auth:

```bash
make configure TFEORG=<your_TFC_organization> TFEUSER=<your_TFC_user> SECRETSFILE=<your_preferred_path>/<your_secrets_file>.json
```

## Check vault version
```bash
kubectl exec --stdin=true --tty=true vault-0 -n vault -- vault -version
```

## Jenkins pipelines integration

This repo has some Jenkins pipelines examples with Vault integration in the `jenkins` folder. Jenkins deployment with JCasC of this repo configures already a multibranch pipeline using the pipeline as code in `jenkins/Jenkinsfile.valt-tf-vars`.

> NOTE: First build failure
> The first automatic build of the pipelines may fail because of the non-existing previous parameters in Jenkins configuration. Then you need to do a new build of the multi-branch pipelines to successfuly run them with your parameters values.

Jenkins is installed in the `jenkins` namespace:

```bash
kubectl get all -n jenkins
```

The password for the `admin` account is in `jenkins-admin` K8s secret:

```bash
kubectl get secret -n jenkins jenkins-admin -o go-template='{{ index .data "jenkins-admin-password" }}' | base64 -d
```

## Reach Jenkins UI
If you can't expose a `LoadBalancer` service, do a `port-forward` of your Jenkins service in a different terminal:
```bash
kubectl port-forward svc/jenkins -n jenkins 9090:8080 --address 0.0.0.0
```

## Reach Vault UI
If you can't expose a `LoadBalancer` service, do a `port-forward` of your Vault service in a different terminal:
```bash
kubectl port-forward svc/vault -n vault 9200:8200 --address 0.0.0.0
```


Then you should be able to access Jenkins at [http://localhost:9090](http://localhost:9090)

You should have a pipeline already configure in [http://localhost:9090/job/HashiCorp/job/vault-tfe-pipeline/](http://localhost:9090/job/HashiCorp/job/vault-tfe-pipeline/)

## Tekton pipelines example

This repo has also a [Tekton pipelines](https://tekton.dev/) example using HashiCorp Vault integration. Use [this other repo](https://github.com/dcanadillas/tekton-vault) for a complete explained example of the integration with Tekton and Vault.


You can install Tekton in your K8s cluster from this repo (from the `install` folder):

```bash
make tekton
```

Then you can deploy the Tekton pipelines by applying them in your `default` namespace (you can do in other namespaces, but then you need to change the Kubernetes Auth role in Vault to give permissions to that namespace):

```bash
kubectl apply -f ./tekton -n default
```