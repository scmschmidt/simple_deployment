# simple_libvirt

Creates a bunch of virtual machines via libvirt.
It makes use of https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs.


## Example Usage

```
module "simple_libvirt" {

  # Path to the module.
  source = "git::https://github.com/scmschmidt/simple_deployment.git//modules/simple_libvirt"
  
  # URI to libvirtd and used subnet.
  location = qemu:///system"
  subnet   = "172.31.0.0/16"
  
  # The name prefix for our resources.
  name = "sschmidt-spielwiese"

  # Map of the machines to create. Each machine has a unique id with a tuple of 'size' and 'image'.
  machines = {
    1    = ["micro", "sles_15"],
    2    = ["micro", "sles_15.1"],
    "3a" = ["micro", "sles_15.1"],
    "3b" = ["micro", "sles_15.2"],
    4    = ["micro", "sles_15.3"]
  }

  # We need a German keyboard.
  keymap = "de-latin1-nodeadkeys"

  # Our logon user with SSH public key.
  admin_user = "enter"
  admin_user_key = "ssh-rsa ..." 

  # Server and key to register the SLES.
  subscription_registration_key = "..."
  registration_server = "https://scc.suse.com"

  # We also want to logon as root.
  enable_root_login = true
}
```

## Argument Reference

The following arguments are supported:

* `source` (mandatory) 

  Points to the module directory either local (relative to the project folder or remote (GitHub).
  See https://www.terraform.io/language/modules/sources for details.

* `location`  (optional)
  
  URI to access libvirt.
  Default:  qemu:///system
  
* `subnet`  (optional)

  Network for libvirt network.

  Default: 172.31.0.0/16

* `network_bridge` (optional)
  
  The bridge devices (of an existing network) added to the virtual machines. Disables network creation (`subnet`) and enables use of `qemu-guest-agent`."

  Default: (empty)

* `name` (mandatory)  

  Name of the environment. It is used throughout the installation as prefix for the resources.

* `machines` (mandatory)

  Map with unique `id` as key and tuples with the size and image data for the instance: `[size, image]` as data.

  Id is used as an identifier for various resources. The machine name is a catenation of `name` and `id`.
  **Take care, that the `key` is unique! Terraform will always take silently the last hit. "Renaming" of machines can lead to strange effects and might brake your environment!**

  Size is an identifier to select the sizing for the virtual machine. 
  The identifiers must be provided by the file `sizing_libvirt.yaml` in the project root directory, which 
  must contain the identifiers you want to use, which contains sizing for vcpu, memory and disk.
  
  An example can be found in the modules directory.
  
  Image is an identifier to select the correct qcow image for the virtual machine.
  The identifiers and the images must be provided by the file `images_libvirt.yaml`, which 
  must contain the identifiers you want to use, which point to the qcow image.

  An example can be found in the modules directory.

  Having a mapping allows the usage of the same identifier with all three modules. The mapping resolves them into the correct names for AWS, Azure and libvirt.  

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


## Output

The module outputs the following variables:

* `machines` (list)

  The libvirt_domain data for each domain.

* `machine_info` (object)

  Aggregated information for each virtual machine.
  The machine names get used as keys and the value is an object with:
   
  * `id` - The instance id.
  * `size` - The sizing identifier used in the plan.
  * `image` - The image identifier used in the plan.
  * `ip_address` - The (first) IP (of the first interface) for the machine.


## Usage with `qemu:///session`

Using `qemu:///session` comes with a few caveats, but is possible.

The `dmacvicar/libvirt` terraform provider does not honor `qemu:///session` as URI (`location` parameter in this module): https://github.com/dmacvicar/terraform-provider-libvirt/issues/906.

The workaround is to use `location = "qemu:///?name=qemu:///session&socket=/run/user/<UID>>/libvirt/virtqemud-sock"` with the `UID` of the user executing `terraform`.
The socket is created when executing `virsh connect qemu:///session` by the started `/usr/sbin/virtqemud`.
The `virtqemud` has normally a timeout (default 120s), so the socket is not permanent and will vanish if not used. There seems no way to change the default timeout. Best call `virsh connect qemu:///session` before you run `terraform apply` to make sure the socket is present or enter `virsh` with `VIRSH_DEFAULT_CONNECT_URI='qemu:///session' virsh` to keep the socket open.

Connecting via a user session instead of a system session has some implications:
  - Networks cannot be created (missing permission to create network devices).
  - Existing networks created via `qemu:///system` are not available.
  
But it is possible to add interfaces (e.g bridges) of existing networks (created via `qemu:///system`) to a domain/machine.

What needs to be done?

On the KVM host:

  - Create a network (dhcp4 is required) in system mode and remember the used bridge device.
  - Install the `qemu-bridge-helper` (part of  the `qemu-tools` package on SUSE).
  - Make sure the SetUID is set on `qemu-bridge-helper` and it is owned by root (default on SUSE).
  - Make sure you can execute the `qemu-bridge-helper` binary. If you adon't have the permissions, add an ACL to give you or a dedicated group you are a member of the execution and read permission (e.g. `setfacl -m g:virtuser:rx /usr/lib/qemu-bridge-helper`).
  - Add an allow rule for the bridge(s) (`allow virbrN`) or a rule to allow all (`allow all`) to `/etc/qemu/bridge.conf`.

With these steps adding the network bridge of the created network to the machine as user should work.

The qcow2 image which is used for the virtual machine must have:

  - the `qemu-guest-agent` be present (`qemu-guest-agent` package on SUSE),
  - the `qemu-guest-agent.service` be enabled to be started at boot (default on SUSE)

This will allow the provider to use the mandatory guest agent to retrieve IP addresses. 

To switch to user session mode, you have to set a few variables in `main.tf`:

  - `location = "qemu:///?name=qemu:///session&socket=/run/user/<UID>/libvirt/virtqemud-sock"`\
    Replace `<UID>` with your own.
  - `network_bridge = "<BRIDGE>"`\
    Replace `<BRIDGE>` with the bridge used by the network you want to use. Setting this variable (default is empty) disables the network creation (The `subnet` variable has no meaning) and also enables the use of the `qemu-guest-agent`.


Here a list of SLES qcow2 images and their working status:

| Release  | Image | works? |
| ---      | ---   | ---    |
| SLES 12 SP5 | SLES12-SP5-JeOS.x86_64-12.5-OpenStack-Cloud-GM.qcow2 | no (times out -> no `qemu-guest-agent`) |
| SLES 15 SP3 | SLES15-SP3-JeOS.x86_64-15.3-OpenStack-Cloud-QU4.qcow2 | not reliably (seldom IPv6 only) |
| SLES 15 SP4 | SLES15-SP4-Minimal-VM.x86_64-OpenStack-Cloud-QU4.qcow2 | yes |
| SLES 15 SP5 | SLES15-SP5-Minimal-VM.x86_64-Cloud-QU4.qcow2 | yes |
| SLES 15 SP6 | SLES15-SP6-Minimal-VM.x86_64-Cloud-QU4.qcow2 | yes |
| SLES 15 SP7 | SLES15-SP7-Minimal-VM.x86_64-Cloud-GM.qcow2 | yes |
| SLES 16.0 (PublicRC) | SLES-16.0-Minimal-VM.x86_64-Cloud-PublicRC.qcow2 | yes |
| SLES-SAP 16.0 (PublicRC) | SLES-SAP-16.0-Minimal-VM-x86_64-Cloud-PublicRC.qcow2 | yes |

