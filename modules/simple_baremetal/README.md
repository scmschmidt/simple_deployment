# simple_baremetal

Contrary to the other modules, "simple_baremetal" only manages btrfs snapshots of already installed machines.
The idea is to get back to a defined state after testing, which normally is done by re-deploying VMs on KVM or Cloud providers.

The snapshot handling works as follows:

On apply:
  - A snapshot "RECOVERY" is created to return to on destroy.
  - A roll back to a snapshot called "BASELINE" is done, which must exist.
 
On destroy:
  - A roll back to the latest recovery snapshot is done, created on apply.

Rolling back to a snapshot always requires two reboots!

Idempotence is tried to ensured by state files on the target systems.

A baseline snapshot must be prepared: `snapper --config root create -d BASELINE`. 

> :exclamation: The OS must support snapshots via `snapper` and `GRUB` must detect bootable snapshots as described in the SLES documentation! 


## Example Usage

```
module "simple_baremetal" {

  # Path to the module.
  source = "git::https://github.com/scmschmidt/simple_deployment.git//modules/simple_baremetal"
  
  # Map of the present machines. Each machine has a unique id with a tuple of 'size' and 'image'.
  machines = {
    "saptune3-test-sles4sap15sp5"    = "192.168.56.13",
    #2    = ["t3.nano", "sles4sap_15.1"],
    
  }

  # Our logon user with SSH public key.
  admin_user     = "enter"
  admin_user_key = "ssh-rsa ..." 

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