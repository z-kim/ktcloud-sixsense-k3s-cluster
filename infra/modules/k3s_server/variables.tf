variable "name_prefix" {
  type = string
}

variable "subnet_id" {
  type = string
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

variable "tags" {
  type = map(string)
}
