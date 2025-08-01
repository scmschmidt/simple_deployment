# simple_baremetal

Contrary to the other modules, "simple_baremetal" does not deploy systems, but manages btrfs snapshots of already installed machines only.
The idea is to get back to a prepared defined state on apply and return to the current one on destroy.

Snapshot handling is done via `snapper` and only for the root config by now. 
The system must be set up as described here https://documentation.suse.com/de-de/sles/15-SP7/html/SLES-all/cha-snapper.html (or the SLE release you use), which should be the default on SLE or OpenLeap.

The snapshot handling works as follows:

On apply:
  - The current snapshot is remembered.
  - A roll back to the "BASELINE" snapshot - which must exist - is done.
    The system boots into a working copy of it.
 
On destroy:
  - A roll back to the recovery snapshot - created on apply - is done.
    The system boots into the snapshot saved on apply.
  - The working copy of the BASELINE snapshot gets deleted.

## Preparation

A baseline snapshot must be prepared: `snapper --config root create -d BASELINE`. 
On apply a read-write copy of that snapshot is created and booted into.

## Cleanup

If something goes wrong and a destroy does not cleans up correctly:

1. Determine the snapshot to what you want to return to.\
   The number can be found in `/var/lib/simple_baremetal/recovery_snapshot`. 
   If the file has been emptied already, you can find it in the terraform output. Look for `recovery snapshot:`.
   You can always run a `snapper -c root list` and choose a snapshot your liking.

2. Check if you are not already in the chosen snapshot.\
   Run a `snapper -c root list`. A `-` after the snapshot number indicates that the snapshot is the currently used, a "+" indicates that the snapshot will be used at next boot. If both conditions apply a `*` is displayed. \
   Your chosen snapshot should be marked by `*`. If it is a `+`, reboot and check again. If it is a `-`, you are currently in the chosen one, but this will change at the next reboot, so you have to act.

3. Set the chosen snapshot as default.\
   A `btrfs subvolume list -t` gives you the list of all subvolumes. Take the ID from the line with your chosen snapshot. The subvolume is named like `@/.snapshots/<SNAPSHOT NUMBER>/snapshot`. Set the default with `btrfs subvolume set-default <ID> /` and reboot. Check if the chosen snapshot is marked with a `*`.

4. Remove surplus snapshots.\
   Run a `snapper -c root list` and delete all snapshots with the description `BASELINE (working)` with `snapper -c root delete <SNAPSHOT NUMBER>`.


## Example Usage

```
module "simple_baremetal" {

  # Path to the module.
  source = "git::https://github.com/scmschmidt/simple_deployment.git//modules/simple_baremetal"
  
# Map of the present machines. Each machine has a unique id with a tuple of 'size' and 'image'.
  machines = {
    "saptune3-test-sles4sap15sp3"    = "192.168.56.9",
    "saptune3-test-sles4sap15sp7"    = "192.168.56.15"
  }

  # SSH Port.
  ssh_port = 22

  # Timeout for SSH connections.
  ssh_timeout = "3s"

  # Our logon user with SSH privat key.
  admin_user     = "root"
  admin_private_key = file("~/.ssh/id_rsa")

  # Reboot timeouts.
  reboot_go_down_timeout = 45
  reboot_come_up_timeout = 120
  reboot_login_timeout = 40
  reboot_system_timeout = 30
}

# Name and IP address of the bare-metal machines.
output "test_machines_C" {
  value       = {
    for id, data in module.test_landscape_C.machines:
      "${id}" => data
    }
  description = "Some data of bare-metal machines."
}
```

## Argument Reference

The following arguments are supported:

* `source` (mandatory) 

   Points to the module directory either local (relative to the project folder or remote (GitHub)).
   See https://www.terraform.io/language/modules/sources for details.

* `machines` (mandatory)

  Map with unique `id` as key (usually the hostname or FQDN ) and the IP address as value.

  Id is simply an identifier and not used in network connections.

  **Take care, that the `id` is unique! Terraform will always take silently the last hit.**

* `ssh_port` (optional)

  Port used for SSH.
  
  Default: 22 

* `admin_user` (optional)
   
  The unprivileged user to logon to the machine.
  
  Default: enter

* `admin_private_key` (mandatory)
  
  The SSH private key for the admin user to logon to the machine.
  

* `ssh_timeout` (optional)
  Timeout for SSH connections. Use suffixes like s (seconds) or m (minutes).

  Default: 10s

* `reboot_go_down_timeout` (optional) 
  Go down timeout for 'rebooter' script in seconds.

  Default: 45

* `reboot_come_up_timeout` (optional)
  Come up timeout for 'rebooter' script in seconds.

  Default: 120

* `reboot_login_timeout` (optional)
  Login timeout for 'rebooter' script in seconds.

  Default: 40

* `reboot_system_timeout` (optional)
  
  System up timeout for 'rebooter' script in seconds.
  default 30


## Output

The module outputs the following variables:

* `machine_info` (object)

  Simply the given machine map:
   
  * `id` - The given id (hostname, FQDN, etc.).
  * `ip_address` - The given IP address or FQDN to reach the host.
