resource "null_resource" "machine" {

  for_each      = toset(keys(var.machines))

  # Triggers have to be used for variables to be available at destroy-time.
  triggers = {
    ssh_port               = var.ssh_port
    admin_user             = var.admin_user
    admin_private_key      = var.admin_private_key
    ssh_timeout            = var.ssh_timeout
    reboot_go_down_timeout = var.reboot_go_down_timeout
    reboot_come_up_timeout = var.reboot_come_up_timeout
    reboot_login_timeout   = var.reboot_login_timeout
    reboot_system_timeout  = var.reboot_system_timeout
    hostname               = "${each.key}"
    address                = var.machines[each.key]
    timestamp              = timestamp()
  }

  connection {
    type           = "ssh"
    port           = "${self.triggers.ssh_port}"
    user           = "${self.triggers.admin_user}"
    private_key    = "${self.triggers.admin_private_key}"
    host           = "${self.triggers.address}"
    timeout        = "${self.triggers.ssh_timeout}"
    agent          = "false"

    # bastion_host	Setting this enables the bastion Host connection. The provisioner will connect to bastion_host first, and then connect from there to host.	
    # bastion_port	The port to use connect to the bastion host.	The value of the port field.
    # bastion_user	The user for the connection to the bastion host.	The value of the user field.
    # bastion_private_key	The contents of an SSH key file to use for the bastion host. These can be loaded from a file on disk using the file function.	The value of the private_key field.
  }

  # Copy scripts to remote machine.
  provisioner "file" {
    source      = "${path.module}/scripts"
    destination = "/var/lib/simple_baremetal"
  }


  # Execution on apply (in the order of appearance!).
  provisioner "remote-exec" {
    inline  = ["bash /var/lib/simple_baremetal/rollback2baseline"]
  }
  provisioner "local-exec" {
    command  = "${path.module}/rebooter ${var.admin_user}@${var.machines[each.key]}"
    environment = {
      SSH_OPTIONS     = "-o StrictHostKeyChecking=no"
      GO_DOWN_TIMEOUT = var.reboot_go_down_timeout
      COME_UP_TIMEOUT = var.reboot_come_up_timeout
      LOGIN_TIMEOUT   = var.reboot_login_timeout
      SYSTEM_TIMEOUT  = var.reboot_system_timeout
    }
  }
  provisioner "remote-exec" {
    inline  = ["bash /var/lib/simple_baremetal/verify_baseline"]
  }

  # Execution on destroy.
  provisioner "remote-exec" {
    when    = destroy
    inline  = ["bash /var/lib/simple_baremetal/rollback2recovery"]
  }
  provisioner "local-exec" {
    when    = destroy
    command  = "${path.module}/rebooter ${self.triggers.admin_user}@${self.triggers.address}"
    environment = {
      SSH_OPTIONS     =  ""
      GO_DOWN_TIMEOUT = "${self.triggers.reboot_go_down_timeout}"
      COME_UP_TIMEOUT = "${self.triggers.reboot_come_up_timeout}"
      LOGIN_TIMEOUT   = "${self.triggers.reboot_login_timeout}"
      SYSTEM_TIMEOUT  = "${self.triggers.reboot_system_timeout}"
    }
  }
  provisioner "remote-exec" {
    when    = destroy
    inline  = ["bash /var/lib/simple_baremetal/cleanup"]
  }

}
