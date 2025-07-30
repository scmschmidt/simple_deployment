variable "machines" {
  description = "Map of machines. Each key is the hostname with the IP address as value."
  type        = map(string)
}

variable "ssh_port" {
  description = "Port used for SSH."
  type        = number
  default     = 22 
}

variable "admin_user" {
  description = "The unprivileged user to logon to the machine."
  type        = string
  default     = "enter"
}

variable "admin_private_key" {
  description = "The SSH private key for the admin user to logon to the machine."
  type        = string
  sensitive   = true
}

variable "ssh_timeout" {
  description = "Timeout for SSH connections. Use suffixes like s (seconds) or m (minutes)."
  type        = string
  default     = "10s"
}

variable "reboot_go_down_timeout" {
  description = "Go down timeout for rebooter script in seconds."
  type        = number
  default     = 45
}

variable "reboot_come_up_timeout" {
  description = "Come up timeout for rebooter script in seconds."
  type        = number
  default     = 120
}

variable "reboot_login_timeout" {
  description = "Login timeout for rebooter script in seconds."
  type        = number
  default     = 40
}

variable "reboot_system_timeout" {
  description = "System up timeout for rebooter script in seconds."
  type        = number
  default     = 30
}
