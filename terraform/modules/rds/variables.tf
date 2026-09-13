variable "environment_name" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "rds_security_group_id" {
  type = string
}

variable "engine_version" {
  type    = string
  default = "16.9"
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "db_name" {
  type    = string
  default = "travelease"
}

variable "master_username" {
  type = string
}

variable "master_password" {
  type      = string
  sensitive = true
}

variable "backup_retention_period" {
  type    = number
  default = 1
}

variable "multi_az" {
  type    = bool
  default = false
}

