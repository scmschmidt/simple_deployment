# simple_aws

Creates a bunch of virtual machines on AWS.
It makes use of https://registry.terraform.io/providers/hashicorp/aws/latest/docs and https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest.

## Example Usage

```
module "test_landscape_A" {

  # Path to the module.
  source = "git::https://github.com/scmschmidt/simple_deployment.git//modules/simple_aws"
  
  # Region and used subnet.
  location = "eu-central-1"
  subnet   = "172.31.0.0/16"
  
  # The name prefix for our resources.
  name = "sschmidt-spielwiese"

  # Map of the machines to create.
  # Each machine has a unique id with a list of 'size', 'image', ssh key slot and
  # reg code slot (see 'admin_user_keys' and 'subscription_registration_keys' below). 
  machines = {
    1    = ["t3.nano", "sles4sap_15", 0, 0],
    2    = ["t3.nano", "sles4sap_15.1", 0, 0],
    "3a" = ["t3.nano", "sles4sap_15.1", 1, 0],
    "3b" = ["t3.nano", "sles4sap_15.2", 1, 0],
    4    = ["t3.nano", "sles4sap_15.3", 0, 0]
  }

  # Bastion host (optional).
  # If declared, machines will get no public IP addresses, but must be accessed via the bastion host.
  # The bastion host has a list of 'size', 'image', ssh key slot and reg code slot
  # (see 'admin_user_keys' and 'subscription_registration_keys' below).
  bastion = ["t3.nano", "sles4sap_12.5", 0, 0]

  # We need a German keyboard.
  keymap = "de-latin1-nodeadkeys"

  # Our logon user with SSH public keys or files containing the key.
  # The key list index is used as slot number in the above machine map.
  admin_user     = "enter"
  admin_user_keys = ["ssh-rsa ...", "@~/.ssh/id_rsa.pub"] 

  # Server and key to register the SLES.
  # The key list index is used as slot number in the above machine map.
  subscription_registration_keys = ["..."]
  registration_server           = "https://scc.suse.com"

  # We also want to logon as root.
  enable_root_login = true
}

# Return the Name, size/image and IP address of each instance, eg.:
output "test_machines" {
  value = [
    for name, info in module.test_landscape_A.machine_info :
    "${name} : ${info.size}/${info.image} -> ${info.ip_address}"
  ]
  description = "Information about the instances."
  sensitive   = false
}
output "bastion" {
  value = [
    module.test_landscape_A.bastion_info.size != "" ? "${module.test_landscape_A.bastion_info.size}/${module.test_landscape_A.bastion_info.image} -> ${module.test_landscape_A.bastion_info.private_ip_address} / ${module.test_landscape_A.bastion_info.public_ip_address}" : ""
  ]
  description = "Information about the bastion instance."
  sensitive   = false
}
```

## Argument Reference

The following arguments are supported:

* `source` (mandatory) 

   Points to the module directory either local (relative to the project folder) or remote (GitHub).
   See https://www.terraform.io/language/modules/sources for details.

* `location`  (mandatory)
  
   The AWS region where everything gets created. To get a list, run: `aws ec2 describe-regions --output table`
  
* `subnet`  (optional)

  Network for the AWS VPC. If a bastion host is used, the network gets divided into two equal subnets (AWS requirement), one for the private subnet with the VMs and one for the public subnet. This reduces the amount of available VMs by half.

  Default: 172.31.0.0/16

* `name` (mandatory)  

  Name of the environment. It is used throughout the installation as prefix for the resources.

* `owner_tag`  (optional)

  Owner of the environment. Used as tag for resources.

  Default: ""

* `managed_by_tag`  (optional)

  Describes what manages the environment. Used as tag for resources.
  
  Default: terraform

* `application_tag`  (optional)
  Application which uses the resources. Used as tag for resources.
  
  Default: ""

* `machines` (mandatory)

  Map with unique `id` as key and a list with the size, the image data, the SSH key slot and registration code slot
  for the instance: `[size, image, ssh_slot, regcode_slot]` as data.

  Id is used as an identifier for various resources. The machine name is a catenation of `name` and `id`.
  **Take care, that the `key` is unique! Terraform will always take silently the last hit. "Renaming" of machines can lead to strange effects and might brake your environment!**

  Size is an identifier to select the sizing for the virtual machine. 
  The identifiers must be provided by the file `sizing_aws.yaml` in the project root directory, which 
  must contain the identifiers you want to use, which point to the AWS instance types. 
  An example can be found in the modules directory.

  Image is an identifier to select the correct AMI for the virtual machine.
  The identifiers and the images must be provided by the file `images_aws.yaml` in the project root directory, which
  must contain the identifiers you want to use, which point to the AMI per region.
  An example can be found in the modules directory.

  Having a mapping allows the usage of the same identifier with all three modules. The mapping resolves them into the correct names for AWS, Azure, GCP and libvirt. 

  The SSH key slot is the index (starting with 0) of the `admin_user_keys` list. This allows individual SSH public keys for different machines.

  The registration code slot is the index (starting with 0) of the `subscription_registration_keys` list. This allows individual registration codes
  for different machines.

  The SSH key slot and the registration code slot can both be omitted. In this case the first key and regcode of the lists will be taken.

* `keymap` (optional)

  The keymap used on the machines.

  Default: de-latin1-nodeadkeys

* `admin_user` (optional)

  The unprivileged user to logon to the deployed machine.
   
  Default: enter 

* `admin_user_key` (optional) *DEPRECATED*

  The SSH public key for the admin user to logon to the machine.
  Deprecated, but if present it takes precedence over `admin_user_keys`! Internally `admin_user_keys` becomes a list with one element containing the content of `admin_user_key`.

  Default: null 

* `admin_user_keys` (optional)
  
  List of SSH public keys or key files (@ prefix) for the admin and root user to logon to the instances.
  The list index is used as slot number in the machine or bastion host definition.
  This replaces the old `admin_user_key`.

  Default: [] 

* `subscription_registration_key` (optional) *DEPRECATED*

  Subscription registration code to register SLE.
  Deprecated, but if present it takes precedence over `subscription_registration_keys`!  
  Internally `subscription_registration_keys` becomes a list with one element containing the content
  of `subscription_registration_key`.

  Default: "-"

* `subscription_registration_keys` (optional)

  List of subscription registration codes to register SLE. A dash skips (re-)registration.
  The list index is used as slot number in the machine or bastion host definition.
  This replaces the old `admin_user_key`.

  Default: ["-"]
  
* `registration_server` (optional)

  URL to the registration server. A "-" as value skips the registration.
   
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
  * `ip_address` - The IP of the instance (public or private depending on existence of bastion host).

* `bastion_info` (object)

  Aggregated information of the optional bastion instance.
  The value is an object with:

  * `id` - The instance id.
  * `size` - The sizing identifier used in the plan.
  * `image` - The image identifier used in the plan.
  * `public_ip_address` - The public IP of the instance.
  * `private_ip_address` - The private IP of the instance.

## Miscellaneous

* AWS instances need up to a minute to be reachable via SSH after deployment. Be patient. 

* The NAT implementation requires the `subnet` to be divided by 2 in case a bastion host is used. Keep that in mind, when calculating the netmask to have enough space for all hosts.