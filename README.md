# simple_deployment

Some Terraform modules to simply rollout machines on libvirt, AWS and Azure with a unified configuration.

## Motivation & Disclaimer

I created this for my own benefit to easily and fast deploy simple virtual machines do check out things as well as integrate it into my testing pipeline. Therefore the features are limited and continuity between all providers was mandatory.

In short, my requirements are:

* deploy machines on libvirt(KVM), Azure and AWS
* only unified(!) configuration options I really need, like:
  * telling where the machine should be created (libvirt hypervisor URI, AWS Regions, etc.),
  * naming my deployment,
  * defining the (SLE) operating system,
  * **minimal** influence on machine sizing (memory, CPUs, disk size, etc.),
  * amount of machines.
* root access to the machine by ssh key
* logon user with ssh key
* registration on the SCC (or other registration server)
* (a bit more, but this was not doable on libvirt, AWS and Azure all together, so I plan to use Ansible later on)

I'll do bug fixing of cause and also maybe enhance it a bit, but only to the extend of my needs. There are no plans to add stuff for more complex deployments. Feel free to fork and work on your own!  

## Installation

You don't need to clone this repository. It would be enough to reference the git repo in your terraform plan like shown in the examples. Terraform will download and install the modules on initialization.

> :exclamation: Sadly this does not work currently and I still have to figure out why!
> For now clone the repo and use the local path to the module directory you want to use.

If you don't need a provider (meaning, libvirt, Azure or AWS), you can skip the installation part for it. Of cause you can't use the module later on.

###  Install `terraform`

Download terraform from https://www.terraform.io/downloads, unpack the zip contains only one binary) and put the binary in `/usr/local/bin/`.
Don't forget to make it executable.

A `terraform -version` should work and print the downloaded version.

> My modules require a terraform version >= 1.1.0. It does not mean, that they won't work with older ones, but this version was the latest, when I started the project. 

### Install AWS CLI

The steps are also described here: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

Download the latest version, unpack and install it:

```
# curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
# unzip awscliv2.zip
# ./aws/install
```

If everything went fine, a `aws --version` should print the downloaded version.

### Install Azure CLI

The steps are also described here: https://docs.microsoft.com/de-de/cli/azure/install-azure-cli

```
rpm --import https://packages.microsoft.com/keys/microsoft.asc
zypper addrepo --name 'Azure CLI' --check https://packages.microsoft.com/yumrepos/azure-cli azure-cli
zypper install --from azure-cli azure-cli
```

> An older version is available in the SLES/OpenLeap repositories.
>   
> If you want to use the latest package from the Microsoft repositories, remove the ones from the SLE repos first with: `zypper rm -y --clean-deps azure-cli`, before you install the one from the Microsoft repository. 
> Do not update! Otherwise `az` will not work and terminate with: 
>
> `/usr/bin/python3.6: No module named azure.cli.__main__; 'azure.cli' is a package and cannot be directly executed`
>
> If you're already in the mess, reinstall the old SLE package first and follow the steps above: `zypper install  --oldpackage azure-cli-<version>`

### Install libvirt/KVM

Just install everything you need to run KVM/quemu-based virtual machines. 
How to install this, is beyond this guide.


## Configuration

### Setup AWS environment

Go to https://us-east-1.console.aws.amazon.com/iam/home?region=us-east-1&skipRegion=true#/security_credentials and create an Access Key/Secret Access Key if not one is already present.

Run `aws configure` on the command line and provide the key Access Key ID, the Secret Access Key and the default region as minimum. The information are stored in `~/.aws/credentials` and `~/.aws/config`.

To check if authentication works run: `aws ec2 describe-instances` to list available instances.

### Setup Azure environment

Run `az login` which opens a web browser session. Choose the account, authenticate and return to the command line where you have executed `az login`. The browser can be closed.

```
~ # az login
A web browser has been opened at https://login.microsoftonline.com/organizations/oauth2/v2.0/authorize. Please continue the login in the web browser. If no web browser is available or if the web browser fails to open, use device code flow with `az login --use-device-code`.
...
  {
    "cloudName": "AzureCloud",
    ...
    "id": "<subscription_id>",
    ...
  }
]
```

Find the `id` part in the output and set the account: `az account set --subscription "<subscription_id>"`

Next, create a Service Principal: `az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/<subscription_id>`

```
az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/<subscription_id>"
The underlying Active Directory Graph API will be replaced by Microsoft Graph API in a future version of Azure CLI. Please carefully review all breaking changes introduced during this migration: https://docs.microsoft.com/cli/azure/microsoft-graph-migration
Creating 'Contributor' role assignment under scope '/subscriptions/501de51d-cd4c-4a11-a0b6-3b2f0b6f1393'
The output includes credentials that you must protect. Be sure that you do not include these credentials in your code or check the credentials into your source control. For more information, see https://aka.ms/azadsp-cli
{
  "appId": "<appid>",
  "displayName": "...",
  "password": "<password>",
  "tenant": "<tenant>"
}
```
Hashicorp's documentation states, that for terraform to work, the returned data must be made available by exported variables:

```
export ARM_CLIENT_ID="<appid>"
export ARM_CLIENT_SECRET="<password>"
export ARM_SUBSCRIPTION_ID="<subscription_id>>"
export ARM_TENANT_ID="<tenant>"
```

**In my case this was not necessary, but I leave this step in here just in case.**


### Setup libvirt/KVM

How to set this up, is beyond this guide.

## Usage

Here a brief example how to setup some test machines on libvirt, AWS and Azure.
You can find detailed descriptions about how to use the modules here:

* [simple_libvirt](modules/simple_libvirt/README.md)
* [simple_aws](modules/simple_aws/README.md)
* [simple_azure](modules/simple_azure/README.md)

Anyways, you need at least a minor understanding of terraform.

```
# Our test landscapes with two machines per SLES for SAP 15 release on AWS (A), Azure (B) and libvirt (C).

module "test_landscape_A" {
  source   = "../../modules/simple_aws"
  location = "eu-west-1"
  name     = "sschmidt-testlandscape-A"
  machines = [
    ["t3.nano", "sles4sap_15"],
    ["t3.nano", "sles4sap_15"],
    ["t3.nano", "sles4sap_15.1"],
    ["t3.nano", "sles4sap_15.1"],
    ["t3.nano", "sles4sap_15.2"],
    ["t3.nano", "sles4sap_15.2"],
    ["t3.nano", "sles4sap_15.3"],
    ["t3.nano", "sles4sap_15.3"]
  ]
  admin_user_key                = "ssh-rsa ..."
  subscription_registration_key = "INTERNAL-USE-ONLY-f1..."
  enable_root_login             = true
}

module "test_landscape_B" {
  source   = "../../modules/simple_azure"
  location = "westeurope"
  name     = "sschmidt-testlandscape-B"
  machines = [
    ["standard_b1", "sles4sap_15"],
    ["standard_b1", "sles4sap_15"],
    ["standard_b1", "sles4sap_15.1"],
    ["standard_b1", "sles4sap_15.1"],
    ["standard_b1", "sles4sap_15.2"],
    ["standard_b1", "sles4sap_15.2"],
    ["standard_b1", "sles4sap_15.3"],
    ["standard_b1", "sles4sap_15.3"]
  ]
  admin_user_key                = "ssh-rsa ..."
  subscription_registration_key = "INTERNAL-USE-ONLY-f1..."
  enable_root_login             = true
}

module "test_landscape_C" {
  source   = "../../modules/simple_libvirt"
  name     = "sschmidt-testlandscape-C"
  machines = [
    ["micro", "sles_15"],
    ["micro", "sles_15"],
    ["micro", "sles_15.1"],
    ["micro", "sles_15.1"],
    ["micro", "sles_15.2"],
    ["micro", "sles_15.2"],
    ["micro", "sles_15.3"],
    ["micro", "sles_15.3"]
  ]
  admin_user_key                = "ssh-rsa ..."
  subscription_registration_key = "INTERNAL-USE-ONLY-f1..."
  enable_root_login             = true
}


# Name, size, image and IP address of the deployed machines.

output "test_machines_A" {
  value = [
    for name, info in module.test_landscape_A.machine_info :
    "${name} : ${info.size}/${info.image} -> ${info.ip_address}"
  ]
}

output "test_machines_B" {
  value = [
    for name, info in module.test_landscape_B.machine_info :
    "${name} : ${info.size}/${info.image} -> ${info.ip_address}"
  ]
}

output "test_machines_C" {
  value = [
    for name, info in module.test_landscape_C.machine_info :
    "${name} : ${info.size}/${info.image} -> ${info.ip_address}"
  ]
}

```
After `terraform init` and `terraform apply` we get at the end the output:

```
...
Apply complete! Resources: 23 added, 0 changed, 0 destroyed.

Outputs:

test_machines_A = [
  "sschmidt-testlandscape-A-0 : t3.nano/sles4sap_15 -> 34.245.45.135",
  "sschmidt-testlandscape-A-1 : t3.nano/sles4sap_15 -> 54.154.207.236",
  "sschmidt-testlandscape-A-2 : t3.nano/sles4sap_15.1 -> 34.245.168.131",
  "sschmidt-testlandscape-A-3 : t3.nano/sles4sap_15.1 -> 54.155.156.5",
  "sschmidt-testlandscape-A-4 : t3.nano/sles4sap_15.2 -> 52.211.229.92",
  "sschmidt-testlandscape-A-5 : t3.nano/sles4sap_15.2 -> 54.154.136.163",
  "sschmidt-testlandscape-A-6 : t3.nano/sles4sap_15.3 -> 34.240.45.133",
  "sschmidt-testlandscape-A-7 : t3.nano/sles4sap_15.3 -> 34.244.251.98",
]

test_machines_B = [
  "sschmidt-testlandscape-B-0 : standard_b1/sles4sap_15 -> 137.116.221.168",
  "sschmidt-testlandscape-B-1 : standard_b1/sles4sap_15 -> 20.224.248.88",
  "sschmidt-testlandscape-B-2 : standard_b1/sles4sap_15.1 -> 20.224.255.211",
  "sschmidt-testlandscape-B-3 : standard_b1/sles4sap_15.1 -> 20.224.254.154",
  "sschmidt-testlandscape-B-4 : standard_b1/sles4sap_15.2 -> 20.224.252.93",
  "sschmidt-testlandscape-B-5 : standard_b1/sles4sap_15.2 -> 20.224.249.16",
  "sschmidt-testlandscape-B-6 : standard_b1/sles4sap_15.3 -> 13.81.68.71",
  "sschmidt-testlandscape-B-7 : standard_b1/sles4sap_15.3 -> 20.224.255.224",
]

test_machines_C = [
  "sschmidt-testlandscape-C-0 : micro/sles_15 -> 172.31.191.116",
  "sschmidt-testlandscape-C-1 : micro/sles_15 -> 172.31.83.231",
  "sschmidt-testlandscape-C-2 : micro/sles_15.1 -> 172.31.30.92",
  "sschmidt-testlandscape-C-3 : micro/sles_15.1 -> 172.31.0.52",
  "sschmidt-testlandscape-C-4 : micro/sles_15.2 -> 172.31.185.59",
  "sschmidt-testlandscape-C-5 : micro/sles_15.2 -> 172.31.63.76",
  "sschmidt-testlandscape-C-6 : micro/sles_15.3 -> 172.31.205.179",
  "sschmidt-testlandscape-C-7 : micro/sles_15.3 -> 172.31.253.48",
]
```

## Changelog

[Link to the CHANGELOG](CHANGELOG.md)
