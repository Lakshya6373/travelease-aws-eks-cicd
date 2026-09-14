variable "environment_name" {
  type = string
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name — used for kubernetes.io/cluster/* subnet tags required by ALB controller"
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "availability_zones" {
  type = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}

