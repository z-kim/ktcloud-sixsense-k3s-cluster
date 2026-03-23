variable "name_prefix" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}

variable "sg_id" {
  type = string
}

variable "listener_port" {
  type = number
}

variable "target_port" {
  type = number
}

variable "tags" {
  type = map(string)
}
