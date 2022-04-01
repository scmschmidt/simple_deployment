# simple_azure

Creates a bunch of virtual machines on Azure.
It makes use of https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs.


## Example Usage

```
module "simple_azure" {

  # Path to the module.
  source = ""github.com/hashicorp/example"./modules/simple_azure" CHANGE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!1
  
  # Region and used subnet.
  location = "westeurope"
  subnet   = "172.31.0.0/16"
  
  # The name prefix for our resources.
  name = "sschmidt-spielwiese"

  # Operating system and instance type.
  image = "sles4sap_12.5"
  size  = "standard_b1"

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

  # We need only one instance for now.
  amount = 1
}
```

## Argument Reference

The following arguments are supported:

* `source` (mandatory) 

   Points to the module directory either local (relative to the project folder or remote (GitHub).
   See https://www.terraform.io/language/modules/sources for details.

* `location`  (mandatory)
  
   The Azure location where everything gets created. To get a list, run: `az account list-locations -o table`
  
* `subnet`  (optional)

  Network for Azure's virtual network.

  Default: 172.31.0.0/16

* `name` (mandatory)  

  Name of the environment. It is used throughout the installation as prefix for the resources.

* `image` (mandatory)

  Identifier to select the correct AMI for the virtual machine.
  The identifiers and the images must be provided by the file `images_azure.yaml`in the project root directory! 
  This file must contain the identifiers you want to use, which point to the AMI. The available images may depend on the location.

  An example can be found in the modules directory.

* `size` (mandatory)

  Identifier to select the sizing for the virtual machine. 
  The identifiers must be provided by the file `sizing_azure.yaml` in the project root directory! 
  The file must contain the identifiers you want to use, which point to the identifiers used by Azure.. 

  An example can be found in the modules directory.

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
  
* `amount` (optional)

  So many instances of this machine description get created.
   
  Default:      1 


## Output

The module ootputs the following variables:

* `machine_address` (list)

   The public IP address of all instance.

* `machine_name` (list)

   The names of all instances.