variable "name_prefix" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "key_name" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "server_private_ip" {
  type = string
}

variable "k3s_token" {
  type      = string
  sensitive = true
}

variable "desired_size" {
  type = number
}

variable "min_size" {
  type = number
}

variable "max_size" {
  type = number
}

variable "target_group_arns" {
  type = list(string)
}

variable "tags" {
  type = map(string)
}
