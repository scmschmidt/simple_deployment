# simple_baremetal

Contrary to the other modules, "simple_baremetal" only manages btrfs snapshots  of already installed machines.
The idea is to get back to a defined state after testing, which normally is done by redeploying VMs on KVM or Cloud providers.

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