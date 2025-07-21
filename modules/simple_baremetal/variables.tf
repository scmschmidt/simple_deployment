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
  description = "The unpriviledged user to logon to the machine."
  type        = string
  default     = "enter"
}

variable "admin_private_key" {
  description = "The SSH private key for the admin unser to logon to the machine."
  type        = string
  sensitive   = true
}

variable "ssh_timeout" {
  description = "Timeout for SSH connections. Use suffixes like s (seconds) or m (minutes)."
  type        = string
  default     = "10s"
}

variable "run_on_apply" {
  description = "Path to a script copied to the host and executed there on apply."
  type        = string
}

variable "run_on_destroy" {
  description = "Path to a script copied to the host and executed there on destroy."
  type        = string
}

