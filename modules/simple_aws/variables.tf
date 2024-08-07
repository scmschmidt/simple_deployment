variable "location" {
  description = "AWS Region"
  type        = string
}

variable "subnet" {
  description = "Subnet for VPC and used for the IP addresses for the virtual machines."
  type        = string
  default     = "172.31.0.0/16"
}

variable "name" {
  description = "Name for the environment and used as identifier for hostnames, network, etc."
  type        = string
}

variable "owner_tag" {
  description = "Owner of the environment. Used as tag for resources."
  type        = string
  default     = ""
}

variable "managed_by_tag" {
  description = "Describes what manages the environment. Used as tag for resources."
  type        = string
  default     = "terraform"
}

variable "application_tag" {
  description = "Application which uses the resources. Used as tag for resources."
  type        = string
  default     = ""
}

variable "machines" {
  description = "Map of machine definitions to deploy. Each key is a unique identifier with a tupel of size identifier and image identifier as value."
  type        = map(list(string))
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
