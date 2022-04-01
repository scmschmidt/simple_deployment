variable "location" {
  description = "URI to libvirt."
  type        = string 
  default     = "qemu:///system"
}

variable "subnet" {
  description = "Subnet for the dhcp range used for the interfaces of the virtual machines."
  type        = string
  default     = "172.31.0.0/16"
}

variable "name" {
  description = "Name for the environment and used as identifier for hostname, image names, etc."
  type        = string
}

variable "image" {
  description = "Identifier for the operating system which points to the actual image."
  type        = string
}

variable "size" {
  description = "Identifier to describe vCPU, memory and disk size requirements for the virtual machine."
  type        = string
}
variable "keymap" {
  description = "The keymap used on the machine."
  type        = string
  default     = "de-latin1-nodeadkeys"
}

variable "admin_user" {
  description = "The unpriviledged user to logon to the deployed machine."
  type        = string
  default     = "enter"
}

variable "admin_user_key" {
  description = "The SSH public key for the admin unser to logon to the machine."
  type        = string
}

variable "subscription_registration_key" {
  description = "Subscription registration code to register SLES."
  type        = string
  default     = "-"
}

variable "registration_server" {
  description = "URL to the registartion server."
  type        = string
  default     = "https://scc.suse.com"
}

variable "enable_root_login" {
  description = "Enable or disable the SSH root login (via admin user key)."
  type        = bool
  default     = false
}

variable "amount" {
  description = "Amount of virtual machines which should be created."
  type        = number
  default     = 1
}
