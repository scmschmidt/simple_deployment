# simple_aws

Creates a bunch of virtual machines on AWS.
It makes use of https://registry.terraform.io/providers/hashicorp/aws/latest/docs, https://registry.terraform.io/providers/hashicorp/aws/latest/docs and https://registry.terraform.io/providers/skeggse/metadata/latest/docs.

## Example Usage

```
module "simple_aws" {

  # Path to the module.
  #source = "git::https://github.com/scmschmidt/simple_deployment.git//modules/simple_aws" # Does not work currently. :-/
  source = "./modules/simple_aws"  # Point to the module directory after you have cloned/downloaded the repo.
  
  # Region and used subnet.
  location = "eu-central-1"
  subnet   = "172.31.0.0/16"
  
  # The name prefix for our resources.
  name = "sschmidt-spielwiese"

  # List of the machines to create. Each machine is a tuple of 'size' and 'image'.
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

  # We need a German keyboard.
  keymap = "de-latin1-nodeadkeys"

  # Our logon user with SSH public key.
  admin_user     = "enter"
  admin_user_key = "ssh-rsa ..." 

  # Server and key to register the SLES.
  subscription_registration_key = "***REMOVED***"
  registration_server           = "https://scc.suse.com"

  # We also want to logon as root.
  enable_root_login = true
}

# Return the Name, size/image and IP address of each instance, eg.:
#   test_machines_A = [
#     "sschmidt-testlandscape-A-0 : t3.nano/sles4sap_15 -> 34.245.45.135",
#     "sschmidt-testlandscape-A-1 : t3.nano/sles4sap_15 -> 54.154.207.236",
#     ...
output "test_machines" {
  value = [
    for name, info in module.test_landscape_A.machine_info :
    "${name} : ${info.size}/${info.image} -> ${info.ip_address}"
  ]
  description = "Information about the instances."
  sensitive   = false
}
```

## Argument Reference

The following arguments are supported:

* `source` (mandatory) 

   Points to the module directory either local (relative to the project folder or remote (GitHub).
   See https://www.terraform.io/language/modules/sources for details.

* `location`  (mandatory)
  
   The AWS region where everything gets created. To get a list, run: `aws ec2 describe-regions --output table`
  
* `subnet`  (optional)

  Network for the AWS VPC.

  Default: 172.31.0.0/16

* `name` (mandatory)  

  Name of the environment. It is used throughout the installation as prefix for the resources.

* `machines` (mandatory)

  List of tuples with the size and image data for the instance: `[size, image]`

  Size is an identifier to select the sizing for the virtual machine. 
  The identifiers must be provided by the file `sizing_aws.yaml` in the project root directory, which 
  must contain the identifiers you want to use, which point to the AWS instance types. 
  
  An example can be found in the modules directory.
  
  Image is an identifier to select the correct AMI for the virtual machine.
  The identifiers and the images must be provided by the file `images_aws.yaml` in the project root directory, which
  must contain the identifiers you want to use, which point to the AMI per region.

  An example can be found in the modules directory.

  The idea to use a mapping instead of the provider identifiers is to provide a way to have common identifiers for all providers. 
  For example It would be possible to use always a size of 'medium' or an image  of 'sles12_sp1' which get translated
  to the correct identifiers for AWS, Azure and libvirt.  

* `keymap` (optional)

  The keymap used on the machines.

  Default: de-latin1-nodeadkeys

* `admin_user` (optional)

  The unprivileged user to logon to the deployed machine.
   
  Default: enter 

* `admin_user_key` (mandatory)
   
  The SSH public key for the admin user to logon to the machine.

* `subscription_registration_key` (optional)
   
  Subscription registration code to register SLES.
  
  Default: "-"
  
* `registration_server` (optional)

  URL to the registartion server.
   
  Default:      https://scc.suse.com
   
* `enable_root_login` (optional)

  Enable or disable the SSH root login (with `admin user key`).
  
  Default:      false 
  

## Output

The module outputs the following variables:

* `machines` (list)

  The aws_instance data for each instance.

* `machine_info` (object)

  Aggregated information for each instance.
  The instance names get used as keys and the value is an object with:
   
  * `id` - The instance id.
  * `size` - The sizing identifier used in the plan.
  * `image` - The image identifier used in the plan.
  * `ip_address` - The public IP for the instance.
