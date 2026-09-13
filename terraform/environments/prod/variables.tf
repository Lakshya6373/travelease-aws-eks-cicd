variable "environment_name"     { type = string; default = "prod" }
variable "region"               { type = string; default = "ap-south-1" }
variable "vpc_cidr"             { type = string }
variable "public_subnet_cidrs"  { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
variable "availability_zones"   { type = list(string) }
variable "node_instance_types"  { type = list(string) }
variable "node_min_size"        { type = number }
variable "node_max_size"        { type = number }
variable "node_desired_size"    { type = number }
variable "rds_instance_class"   { type = string }
variable "backup_retention_period" { type = number }
variable "enable_waf"           { type = bool }
variable "db_master_username"   { type = string; default = "travelease" }
variable "db_master_password"   { type = string; sensitive = true }
variable "jwt_secret"           { type = string; sensitive = true }
