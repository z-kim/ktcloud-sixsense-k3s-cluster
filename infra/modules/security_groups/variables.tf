variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "admin_cidrs" {
  type = list(string)
}

variable "ingress_http_nodeport" {
  type = number
}

variable "ingress_https_nodeport" {
  type = number
}

variable "tags" {
  type = map(string)
}
