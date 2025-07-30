resource "null_resource" "machine" {

  for_each      = toset(values(var.machines))

  # Triggers have to be used for variables to be available at destroy-time.
  triggers = {
    ssh_port          = var.ssh_port
    admin_user        = var.admin_user
    admin_private_key = var.admin_private_key
    ssh_timeout       = var.ssh_timeout
    run_on_destroy    = var.run_on_destroy
  }

  connection {
    type           = "ssh"
    port           = "${self.triggers.ssh_port}"
    user           = "${self.triggers.admin_user}"
    private_key    = "${self.triggers.admin_private_key}"
    host           = each.key
    timeout        = "${self.triggers.ssh_timeout}"

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
    inline  = ["bash /var/lib/simple_baremetal/scripts/rollback2baseline"]
  }
  provisioner "local-exec" {
    command  = "${path.module}/rebooter ${var.admin_user}@${each.key}"
    environment = {
      SSH_OPTIONS     =  ""
      GO_DOWN_TIMEOUT =  45
      COME_UP_TIMEOUT = 120
      LOGIN_TIMEOUT   =  40
      SYSTEM_TIMEOUT  =  30
    }
  }
  provisioner "remote-exec" {
    inline  = ["bash /var/lib/simple_baremetal/scripts/verify_baseline"]
  }

  # Execution on destroy.
  provisioner "remote-exec" {
    when    = destroy
    inline  = ["bash /var/lib/simple_baremetal/scripts/rollback2recovery"]
  }
  provisioner "local-exec" {
    when    = destroy
    command  = "${path.module}/rebooter ${self.triggers.admin_user}@${each.key}"
    environment = {
      SSH_OPTIONS     =  ""
      GO_DOWN_TIMEOUT =  45
      COME_UP_TIMEOUT = 120
      LOGIN_TIMEOUT   =  40
      SYSTEM_TIMEOUT  =  30
    }
  }
  provisioner "remote-exec" {
    when    = destroy
    inline  = ["bash /var/lib/simple_baremetal/scripts/cleanup"]
  }

}
