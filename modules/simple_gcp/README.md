# simple_gcp

Creates a bunch of virtual machines on GCP.
It makes use of https://registry.terraform.io/providers/hashicorp/google/latest/docs.

## Example Usage

```
module "simple_gcp" {

  # Path to the module.
  source = "git::https://github.com/scmschmidt/simple_deployment.git//modules/simple_gcp"
  
  # Zone and used subnet.
  location = "europe-west2-a"
  subnet   = "172.31.0.0/16"
  
  # The name prefix for our resources.
  name = "sschmidt-spielwiese"

  # Name of the Google Cloud project.
  project = "simple_deployment"
  
  # Map of the machines to create. Each machine has a unique id with a tuple of 'size' and 'image'.
  machines = {
    1    = ["e2-micro", "sles4sap_15"],
    2    = ["e2-micro", "sles4sap_15.5"],
    "3a" = ["e2-micro", "sles4sap_15.6"],
    "3b" = ["e2-micro", "sles4sap_15.6"],
    4    = ["e2-micro", "sles4sap_15.7"]
  }

  # We need a German keyboard.
  keymap = "de-latin1-nodeadkeys"

  # Our logon user with SSH public key.
  admin_user     = "enter"
  admin_user_key = "ssh-rsa ..." 

  # Server and key to register the SLES.
  subscription_registration_key = "..."
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
    for name, info in module.simple_gcp.machine_info :
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
  
   The GCP zone where everything gets created. To get a list, run: `gcloud compute zones list --sort-by=region`
  
* `subnet`  (optional)

  Network for the AWS VPC.

  Default: 172.31.0.0/16

* `name` (mandatory)  

  Name of the environment. It is used throughout the installation as prefix for the resources.

* `project` (mandatory)  

  Name of the Google Cloud project.

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

  Map with unique `id` as key and tuples with the size and image data for the instance: `[size, image]` as data.

  Id is used as an identifier for various resources. The machine name is a catenation of `name` and `id`.
  **Take care, that the `key` is unique! Terraform will always take silently the last hit. "Renaming" of machines can lead to strange effects and might brake your environment!**

  Size is an identifier to select the sizing for the virtual machine. 
  The identifiers must be provided by the file `sizing_gcp.yaml` in the project root directory, which  must contain the identifiers you want to use, which point to the GCP instance types. 
  
  An example can be found in the modules directory.
  
  Image is an identifier to select the correct image for the virtual machine.
  The identifiers and the images must be provided by the file `images_gcp.yaml` in the project root directory, which must contain the identifiers you want to use, which point to the image.

  An example can be found in the modules directory.

  Having a mapping allows the usage of the same identifier with all three modules. The mapping resolves them into the correct names for AWS, Azure, GCP and libvirt.   

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

  URL to the registration server. A "-" as value skips the registration.
   
  Default:      https://scc.suse.com
   
* `enable_root_login` (optional)

  Enable or disable the SSH root login (with `admin user key`).
  
  Default:      false 
  

## Output

The module outputs the following variables:

* `machines` (list)

  The gcp_instance data for each instance.

* `machine_info` (object)

  Aggregated information for each instance.
  The instance names get used as keys and the value is an object with:
   
  * `id` - The instance id.
  * `size` - The sizing identifier used in the plan.
  * `image` - The image identifier used in the plan.
  * `ip_address` - The public IP for the instance.
