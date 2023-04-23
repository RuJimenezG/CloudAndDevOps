# Variables de la base de datos

variable "database_name" {
  description = "Value of the database name"
  type        = string
  default     = "NombreBaseDatos"
}

variable "database_identifier" {
  description = "Value of the database identifier"
  type        = string
  default     = "identificadorbasedatos"
}

variable "user_name" {
  description = "Value of the database user name"
  type        = string
  default     = "userbasedatos"
}

variable "db_password" {
  description = "Value of the database password"
  type        = string
  default     = "ponunabuenapasswordaqui"
}

# Variables de la VPC

variable "sec_group" {
  description = "Value of the security group id"
  type        = string
  default     = "security-group-id"
}

variable "subnet_id1" {
  description = "Value of the 1st subnet id"
  type        = string
  default     = "subnet1-id"
}

variable "subnet_id2" {
  description = "Value of the 2nd subnet id"
  type        = string
  default     = "subnet2-id"
}