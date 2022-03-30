# CI/CD Pipelines Vault Integration

Example of Vault integration with CI/CD pipelines

## Requirements

* Running K8s cluster
* `kubectl` CLI installed
* Helm CLI installed
* A Terraform Cloud user and organization (some of the example pipelines do a TFC run)


## Installation

Install Vault and Jenkins without providing AWS credentials (in a json file):
```bash
cd install
make jenkins
```

The script will ask to you to provide AWS_ACCESS_KEY, AWS_SECRET_KEY and AWS_SESSION_TOKEN.
The AWS_SESSION_TOKEN is mandatory for Vault aws secrets engine because it will be configured with the usage of
sts-assume role.

Install Vault and Jenkins providing AWS credentials (in a json file):
```bash
cp template/aws_credentials.json <path_you_prefer>
```
Edit file and put on it all the AWS credentials needed (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY and AWS_SESSION_TOKEN)
```
cd install
make jenkins <path_you_prefer>/aws_credentials.json
```

The script is going to ask if you are using the righ K8s context. Press any key to continue or Crtl'C to cancel.

> NOTE:
> *If you want to install every included CI/CD engine (Tekton Pipelines by now):*
> ```bash
> make install
> ```

Copy the template file (secrets.json) in another folder and write your personal secrets: this new file will be the one you'll
use in the next step.
> ```bash
> cp install/config/secrets.json <your_preferred_path>/<your_secrets_file>.json
> ```

Use the new static secrets file to create your own and apply your custom values:
```json
{
  "tfe_org": "<your_tfc_org>",
  "tfe_token": "<static_example_tfe_token>",
  "gh_user": "<gh_token>",
  "gh_token": "<gh_token> "
}
```

Copy the template file (tfe_values.json) in another folder and write on it your TFC workspace variable: this new file will be the one you'll use in the next step.

```json
{
  "<tfc_variable_name_1>": "<value_to_be_set>",
  "<tfc_variable_name_2>": "<value_to_be_set>",
  "..." : "...",
  "<tfc_variable_name_n>": "<value_to_be_set>"
}
```

Configure Vault with the required secrets and Kubernetes auth:
```bash
make configure TFEORG=<your_TFC_organization> TFEUSER=<your_TFC_user> SECRETSFILE=<your_preferred_path>/<your_secrets_file>.json
```

## Enable AWS Auth Method
Create an AWS IAM role with at least AmazonEC2FullAccess and add trust relationship for a specific user into a specific account
Here is a link that explains how does it work: [https://aws.amazon.com/blogs/security/how-to-use-trust-policies-with-iam-roles] (https://aws.amazon.com/blogs/security/how-to-use-trust-policies-with-iam-roles/)

Each AWS IAM role has a "trust policy" which specifies which entities are trusted to call sts:AssumeRole on the role and retrieve credentials that can be used to authenticate with that role. When AssumeRole is called, a parameter called RoleSessionName is passed in, which is chosen arbitrarily by the entity which calls AssumeRole. If you have a role with an ARN arn:aws:iam::123456789012:role/MyRole, then the credentials returned by calling AssumeRole on that role will be arn:aws:sts::123456789012:assumed-role/MyRole/RoleSessionName where RoleSessionName is the session name in the AssumeRole API call. It is this latter value which Vault actually sees.

Configure Vault with AWS authentication method:
```bash
make awsauth ROLEARN=<your_role_arn>
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