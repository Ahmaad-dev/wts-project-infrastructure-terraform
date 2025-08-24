variable "prefix" {
  type        = string
  default     = "swedencentral"
  description = "Prefix for all resources"
}

variable "location" {
  type        = string
  default     = "Sweden Central"
  description = "Azure Region"
}

variable "rg_name" {
  type        = string
  description = "Resource Group Name"
}

variable "acr_name" {
  type        = string
  description = "Azure Container Registry Name"
}

variable "kv_name" {
  type        = string
  description = "Key Vault Name"
}

variable "sa_name" {
  type        = string
  description = "Storage Account Name"
}

variable "cae_name" {
  type        = string
  default     = "cae-swe-wts"
  description = "Container App Environment Name"
}

variable "ca_name" {
  type        = string
  default     = "ca-swe-wts-backend"
  description = "Container App Name"
}

variable "mi_name" {
  type        = string
  default     = "mi-fh-projects-github"
  description = "Name der existierenden User Assigned Managed Identity"
}

variable "image_tag" {
  type        = string
  default     = "latest"
  description = "Container image tag"
}

variable "api_port" {
  type        = number
  default     = 8080
  description = "API Port"
}
variable "allowed_origins" {
  type        = list(string)
  default     = []
  description = "Allowed Origins"
}

# Existierende Ressourcen in fh-manuals
variable "existing_rg_name" {
  type        = string
  default     = "fh-manuals"
  description = "Name der existierenden Resource Group mit UAMI und Storage Account"
}

# Azure SQL Database Konfiguration
variable "sql_server_name" {
  type        = string
  description = "Azure SQL Server Name"
}

variable "sql_database_name" {
  type        = string
  default     = "wts-project-db"
  description = "Azure SQL Database Name"
}

variable "sql_admin_username" {
  type        = string
  default     = "sqladmin"
  description = "SQL Server Admin Username"
}