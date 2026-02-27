variable "location" {
  description = "GCP Zone"
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

variable "project" {
  description = "Project name in GCP."
  type        = string
}

variable "machines" {
  description = "Map of machine definitions to deploy. Each key is a unique identifier with a tuple of size identifier, image identifier, SSH key index (optional) and registration key index (optional) as value."
  type        = map(list(string))
}

variable "bastion" {
  description = "List with bastion host definition to deploy. First entry is a size identifier and the second the image identifier, the third the SSH key index and the fourth registration key index."
  type        = list(string)
  default     = []
}

variable "keymap" {
  description = "The keymap used on the machine."
  type        = string
  default     = "de-latin1-nodeadkeys"
}

variable "admin_user" {
  description = "The unprivileged user to logon to the deployed machine."
  type        = string
  default     = "enter"
}

variable "admin_user_key" {
  description = "The SSH public key for the admin and root user to logon to the instances. (Deprecated! 'admin_user_keys' should be used instead.)"
  type        = string
  default     = null
}

variable "admin_user_keys" {
  description = "List of SSH public keys or key files (@ prefix) for the admin and root user to logon to the instances."
  type        = list(string)
  default     = []
}

variable "subscription_registration_key" {
  description = "Subscription registration code to register SLES. (Deprecated! 'admin_user_keys' should be used instead.)"
  type        = string
  default     = null
}

variable "subscription_registration_keys" {
  description = "List of subscription registration codes to register SLES."
  type        = list(string)
  default     = []
}

variable "registration_server" {
  description = "URL to the registration server.  A dash skips (re-)registration."
  type        = string
  default     = "https://scc.suse.com"
}

variable "enable_root_login" {
  description = "Enable or disable the SSH root login (via admin user key)."
  type        = bool
  default     = false
}
