# simple_deployment

Some terraform modules to simply rollout machines on libvirt, AWS, GCP and Azure with a "unified" configuration.
For bare-metal an SSH-based module is available to manage btrfs snapshots.

## Motivation & Disclaimer

I created this for my own benefit to easily and fast deploy simple virtual machines do check out things as well as integrate it into my testing pipeline. Therefore the features are limited and continuity between all providers was mandatory.

In short, my requirements are:

* deploy machines on libvirt(KVM), Azure, GCP and AWS
* only unified(!) configuration options I really need, like:
  * telling where the machine should be created (libvirt hypervisor URI, AWS Regions, etc.),
  * naming my deployment,
  * defining the (SLE) operating system,
  * **minimal** influence on machine sizing (memory, CPUs, disk size, etc.),
  * amount of machines.
* ICMP and SSH are allowed
* bastion host is supported on most providers
* root access to the machine by ssh key
* logon user with ssh key
* registration on the SCC (or other registration server)

I'll do bug fixing of cause and also maybe enhance it a bit, but only to the extend of my needs. There are no plans to add stuff for more complex deployments. Feel free to fork and work on your own!

> :exclamation: The bare-metal module is different because it just manages btrfs snapshots.

## Installation

You don't need to clone this repository. It would be enough to reference the git repo in your terraform plan like shown in the examples. Terraform will download and install the modules on initialization.

###  Install `terraform`

Download terraform from https://www.terraform.io/downloads, unpack the zip (contains only one binary) and put the binary in `/usr/local/bin/`.
Don't forget to make it executable.

A `terraform -version` should work and print the downloaded version.

> My modules require a terraform version >= 1.1.0. It does not mean, that they won't work with older ones, but this version was the latest, when I started the project. 

### Install AWS CLI

The steps are also described here: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

Download the latest version, unpack and install it:

```
# curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscli.zip"
# unzip awscli.zip
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

If everything went fine, a `az version` should print the downloaded version.


> An older version is available in the SLES/OpenLeap repositories.
>   
> If you want to use the latest package from the Microsoft repositories, remove the ones from the SLE repos first with: `zypper rm -y --clean-deps azure-cli`, before you install the one from the Microsoft repository. 
> Do not update! Otherwise `az` will not work and terminate with: 
>
> `/usr/bin/python3.6: No module named azure.cli.__main__; 'azure.cli' is a package and cannot be directly executed`
>
> If you're already in the mess, reinstall the old SLE package first and follow the steps above: `zypper install  --oldpackage azure-cli-<version>`

### Install GCP CLI

The steps are also described here: https://docs.microsoft.com/de-de/cli/azure/install-azure-cli

```
zypper addrepo -f https://packages.cloud.google.com/yum/repos/cloud-sdk-el8-x86_64 google-cloud-sdk
zypper in google-cloud-cli
```

If everything went fine, a `gcloud version` should print the downloaded version.

### Install libvirt/KVM

Just install everything you need to run KVM/quemu-based virtual machines. 
How to install this, is beyond this guide.


## Configuration

### Setup AWS environment

Setup SSO as documented by AWS and run `aws sso login` to update your credentials when `terraform` complains.

### Setup Azure environment

Setup logon as documented by Microsoft and run `az login` to update your credentials when `terraform` complains.

### Setup GCP environment

Setup logon as documented by Google and run `gcloud auth login` to update your credentials when `terraform` complains.

### Setup libvirt/KVM

How to set this up, is beyond this guide.

### Setup bare-metal

The systems must be installed and reachable via SSH whith key-based authentication. No interaction must be necessary on logon. A snapshot `BASELINE` must be present. See [simple_baremetal](modules/simple_baremetal/README.md) for details.

## Usage

Here a brief example how to setup some test machines on libvirt, AWS and Azure.
You can find detailed descriptions about how to use the modules here:

* [simple_libvirt](modules/simple_libvirt/README.md)
* [simple_aws](modules/simple_aws/README.md)
* [simple_azure](modules/simple_azure/README.md)
* [simple_gcp](modules/simple_gcp/README.md)
* [simple_baremetal](modules/simple_baremetal/README.md)

Anyway, you need at least a minor understanding of terraform.

```
# Our test landscapes with some machines with SLES for SAP applications 15 releases on AWS (A), Azure (B), libvirt (C) and GCP(D).
# Only minimal sensible configuration is done. There is more available!

module "test_landscape_A" {
  source   = "git::https://github.com/scmschmidt/simple_deployment.git//modules/simple_aws"
  location = "eu-central-1"
  name     = "sschmidt-testlandscape"
  machines = {
    "1"    = ["t3.nano", "sles4sap_15.6"],
    "2"    = ["t3.nano", "sles4sap_15.7"],
  }
  admin_user_key                = "ssh-rsa ..."
  subscription_registration_key = "INTERNAL-USE-ONLY-f1..."
  enable_root_login             = true
}

module "test_landscape_B" {
  source   = "git::https://github.com/scmschmidt/simple_deployment.git//modules/simple_azure"
  location = "westeurope"
  name     = "sschmidt-testlandscape"
  machines = {
    "1"    = ["standard_b1", "sles4sap_15.6"],
    "2"    = ["standard_b1", "sles4sap_15.7"],
  }
  admin_user_key                = "ssh-rsa ..."
  subscription_registration_key = "INTERNAL-USE-ONLY-f1..."
  enable_root_login             = true
}

module "test_landscape_C" {
  source   = "git::https://github.com/scmschmidt/simple_deployment.git//modules/simple_libvirt"
  name     = "sschmidt-testlandscape"
  machines = {
    "1"    = ["large", "sles4sap_15.6"],
    "2"    = ["large", "sles4sap_15.7"],
  }
  admin_user_key                = "ssh-rsa ..."
  subscription_registration_key = "INTERNAL-USE-ONLY-f1..."
  enable_root_login             = true
}

module "test_landscape_D" {
  source   = "git::https://github.com/scmschmidt/simple_deployment.git//modules/simple_gcp"
  name     = "sschmidt-testlandscape"
  location = "europe-west2-a"
  project  = "sschmidt-tests"   # project is only available/required on GCP!
  machines = {
    "1"    = ["e2-micro", "sles4sap_15.6"],
    "2"    = ["e2-micro", "sles4sap_15.7"],
  }
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

output "test_machines_D" {
  value = [
    for name, info in module.test_landscape_D.machine_info :
    "${name} : ${info.size}/${info.image} -> ${info.ip_address}"
  ]
}
```
After `terraform init` and `terraform apply` we get at the end the output:

```
...
Outputs:

test_machines_A = [
  "sschmidt-testlandscape-1 : t3.nano/sles4sap_15.6 -> 18.197.132.82",
  "sschmidt-testlandscape-2 : t3.nano/sles4sap_15.7 -> 3.76.214.67",
]
test_machines_B = [
  "sschmidt-testlandscape-1 : standard_b1/sles4sap_15.6 -> 137.117.149.106",
  "sschmidt-testlandscape-2 : standard_b1/sles4sap_15.7 -> 40.113.120.155",
]
test_machines_C = [
  "sschmidt-testlandscape-1 : large/sles4sap_15.6 -> 172.31.58.224",
  "sschmidt-testlandscape-2 : large/sles4sap_15.7 -> 172.31.61.43",
]
test_machines_D = [
  "sschmidt-testlandscape-1 : e2-micro/sles4sap_15.6 -> 34.13.25.126",
  "sschmidt-testlandscape-2 : e2-micro/sles4sap_15.7 -> 34.39.54.226",
]
```

## Peculiarities

### simple_libvirt

- If a machine was shutdowned a `terraform apply` will restart it. The new IP is not known and represented by an empty string. Just run `terraform refresh` to update the IP address.

### simple_azure

- Contrary to the other providers a shutdowned machine will not be detected.

### simple_aws

- It can take up to a minute until deployed machines are reachable. Be patient.
- A shutdowned machine would normally get redeployed, because the IP address is not present anymore. 
  We ignoring changes to the IP address, therefore shutdowned machines get ignored an represented with an empty IP address. If they have been restarted, an additional `terraform apply` or `terraform refresh` is necessary to update the state. Keep in mind, that the newly started machine will get a new IP address!

### simple_gcp

- It can take up to a minute until deployed machines are reachable. Be patient.
- The resource name must match the regex: `^(?:[a-z](?:[-a-z0-9]{0,61}[a-z0-9])?)$`

### simple_baremetal

- This is an exotic foreigner amongst the others. It does not deploys anything, but expects already installed and configured systems. It only switches between btrfs snapshots.

## Changelog

[Link to the CHANGELOG](CHANGELOG.md)
