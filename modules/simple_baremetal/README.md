# simple_baremetal

Contrary to the other modules, "simple_baremetal" does not deploy systems, but manages btrfs snapshots of already installed machines only.
The idea is to get back to a prepared defined state on apply and return to the current one on destroy.
Snapshot handling is done via `snapper`.

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

## Cleanup

If something 
#TODO:




## Example Usage

```
module "simple_baremetal" {

  # Path to the module.
  source = "git::https://github.com/scmschmidt/simple_deployment.git//modules/simple_baremetal"
  
# Map of the present machines. Each machine has a unique id with a tuple of 'size' and 'image'.
  machines = {
    #"saptune3-test-sles4sap15sp3"    = "192.168.56.9",
    "saptune3-test-sles4sap15sp7"    = "192.168.56.15"
  }

  # SSH Port.
  ssh_port = 22

  # Timeout for SSH conncetions.
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


```